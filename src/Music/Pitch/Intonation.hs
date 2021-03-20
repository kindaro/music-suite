{-# LANGUAGE FlexibleContexts #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing
  -fno-warn-unused-imports
  -fno-warn-redundant-constraints #-}

-- | Intonation and tuning.
module Music.Pitch.Intonation
  ( Intonation (..),
    Tuning (..),
    intone,

    -- * Specific tunings
    pythagorean,
    quarterCommaMeantone,
    schismaticMeantone,
    fiveToneEqual,
    sevenToneEqual,
    twelveToneEqual,
    nineteenToneEqual,
    thirtyOneToneEqual,
    fiftyThreeToneEqual,
    just,

    -- * Specific intonations
    standardIntonation,
  )
where

import Control.Applicative
import Control.Lens
import Control.Monad
import Data.AffineSpace
import Data.AffineSpace.Point.Offsets (AffinePair)
import Data.Basis
import Data.Either
import Data.Fixed
import Data.Maybe
import Data.Ratio
import Data.Semigroup
import Data.VectorSpace
import Music.Pitch.Absolute
import Music.Pitch.Common.Internal
import Music.Pitch.Common.Spell
import Music.Pitch.Literal as Intervals

newtype Tuning i = Tuning {getTuning :: i -> Double}

newtype Intonation p = Intonation {getIntonation :: p -> Hertz}

basis_A1 :: Interval
basis_A1 = basisValue Chromatic

basis_d2 :: Interval
basis_d2 = basisValue Diatonic

synTune :: (Interval, Double) -> (Interval, Double) -> Interval -> Double
synTune (i1, i1rat) (i2, i2rat) (view (from intervalAlterationSteps) -> (a1, d2)) =
  (makeA1 (i1, i1rat) (i2, i2rat) ** fromIntegral a1) * (maked2 (i1, i1rat) (i2, i2rat) ** fromIntegral d2)
  where
    makeA1 = makeBasis basis_A1
    maked2 = makeBasis basis_d2

makeBasis :: Interval -> (Interval, Double) -> (Interval, Double) -> Double
makeBasis i (i1, r1) (i2, r2) = case convertBasisFloat i i1 i2 of
  Just (x, y) -> (r1 ** x) * (r2 ** y)
  Nothing -> error ("Cannot use intervals " ++ show i1 ++ " and " ++ show i2 ++ " as basis pair to represent " ++ show i)

-- | Turn a tuning into an intonation by picking a reference pitch and frequency.
intone :: AffinePair v p => Hertz -> p -> Tuning v -> Intonation p
intone f b (Tuning t) = Intonation int
  where
    int p = f .+^ (t i) where i = p .-. b

-- More generally:
-- intone :: AffineSpace p => (p, Hertz) -> Tuning (Diff p) -> Intonation p

-- Standard syntonic (meantone) tunings, with P8 = 2

pureOctaveWith :: (Interval, Double) -> Tuning Interval
pureOctaveWith = Tuning . synTune (_P8, 2)

-- | Pythagorean tuning.
pythagorean :: Tuning Interval
pythagorean = pureOctaveWith (_P5, 3 / 2)

-- | Quarter-comma meantone.
quarterCommaMeantone :: Tuning Interval
quarterCommaMeantone = pureOctaveWith (_M3, 5 / 4)

-- | Schismatic meantone.
schismaticMeantone :: Tuning Interval
schismaticMeantone = pureOctaveWith (8 *^ _P4, 10)

-- TET tunings, i.e. where P8 = 2 and (some other interval) = 1

tetTune :: Interval -> Tuning Interval
tetTune i = pureOctaveWith (i, 1)

-- | 5-tone equal temperament.
fiveToneEqual :: Tuning Interval
fiveToneEqual = tetTune m2

-- | 7-tone equal temperament.
sevenToneEqual :: Tuning Interval
sevenToneEqual = tetTune _A1

-- | 7-tone equal temperament.
twelveToneEqual :: Tuning Interval
twelveToneEqual = tetTune d2

-- | 19-tone equal temperament.
nineteenToneEqual :: Tuning Interval
nineteenToneEqual = tetTune dd2 where dd2 = d2 ^-^ _A1

-- | 31-tone equal temperament.
thirtyOneToneEqual :: Tuning Interval
thirtyOneToneEqual = tetTune dddd3 where dddd3 = m3 ^-^ (4 *^ _A1)

-- | 53-tone equal temperament.
fiftyThreeToneEqual :: Tuning Interval
fiftyThreeToneEqual = tetTune ddddddd6 where ddddddd6 = 31 *^ _P8 ^-^ 53 *^ _P5 -- (!)

-- | Modern standard intonation, i.e. 12-tone equal temperament with @a = 440 Hz@.
standardIntonation :: Intonation Pitch
standardIntonation = intone 440 a twelveToneEqual

-- | Just intonation.
just :: Tuning Interval
just = Tuning justT'

justT' :: Floating a => Interval -> a
justT' i = 2 ** fromIntegral o * go (spell usingSharps s)
  where
    (o, s) = separate i
    go i
      | i == _P1 = 1
      | i == _M2 = 9 / 8
      | i == _M3 = 5 / 4
      | i == _P4 = 4 / 3
      | i == _P5 = 3 / 2
      | i == _M6 = 5 / 3
      | i == _M7 = 15 / 8
      | i == _A1 = (5 / 3) * (5 / 4) / 2
      | i == _A2 = (15 / 8) * (5 / 4) / 2 -- or minor third
      | i == _A4 = (9 / 8) * (5 / 4)
      | i == _A5 = (5 / 4) * (5 / 4)
      | i == _A6 = 7 / 4
      | otherwise = error $ "justT got" ++ show i

{-
Possible instances for numeric types based on standard intonation.

Not used, the user should choose perform the appropriate conversion for a given
tuning system.

instance IsInterval Double where
  fromInterval i = getTuning twelveToneEqual $ fromInterval i

instance IsInterval Float where
    fromInterval x = realToFrac (fromInterval x :: Double)

instance HasResolution a => IsInterval (Fixed a) where
    fromInterval x = realToFrac (fromInterval x :: Double)

instance Integral a => IsInterval (Ratio a) where
    fromInterval x = realToFrac (fromInterval x :: Double)
-}

{-
-- Sort a chord based on dissonance, in C major just intonation
-- Higher value means more dissonant
chordDiss :: Tuning Interval -> [Pitch] -> Hertz
chordDiss tuning = diss . fmap inton
  where
    inton = (getIntonation $ intone (c, 264) tuning)
-- inton = standardIntonation
-}
