
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : portable
--
-- Absolute representation of loudness, or dynamics.
--
-- The canonical loudness representation is 'Amplitude'. For conversion, see 'HasAmplitude'.
module Music.Dynamics.Absolute
  ( Amplitude (..),
    Decibel,
    Bel,
    HasAmplitude (..),
    decibel,
    bel,
  )
where


-- |
-- Amplitude level, where @0@ is silent and @1@ is peak.
newtype Amplitude = Amplitude {getAmplitude :: Double}
  deriving (Show, Eq, Enum, Num, Ord, Fractional, Floating, Real, RealFrac)

-- |
-- A logarithmic representation of amplitude such that
--
-- >
-- > x * 10 = amplitude (bel x + 1)
newtype Bel = Bel {getBel :: Amplitude}
  deriving (Show, Eq, Enum, Num, Ord, Fractional, Floating, Real, RealFrac)

-- |
-- A logarithmic representation of amplitude such that
--
-- >
-- > x * 10 = amplitude (decibel x + 10)
newtype Decibel = Decibel {getDecibel :: Amplitude}
  deriving (Show, Eq, Enum, Num, Ord, Fractional, Floating, Real, RealFrac)

instance Semigroup Amplitude where (<>) = (*)

instance Semigroup Decibel where (<>) = (+)

instance Semigroup Bel where (<>) = (+)

instance Monoid Amplitude where mempty = 1

instance Monoid Decibel where mempty = 0

instance Monoid Bel where mempty = 0

class HasAmplitude a where
  amplitude :: a -> Amplitude

instance HasAmplitude Amplitude where
  amplitude = id

instance HasAmplitude Decibel where
  amplitude (Decibel f) = (10 / 1) ** (f / 10)

instance HasAmplitude Bel where
  amplitude (Bel f) = (10 / 1) ** (f / 1)

decibel :: HasAmplitude a => a -> Decibel
decibel a = Decibel $ logBase (10 / 1) (amplitude a) * 10

bel :: HasAmplitude a => a -> Bel
bel a = Bel $ logBase (10 / 1) (amplitude a) * 1
