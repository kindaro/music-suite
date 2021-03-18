{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC
  -fno-warn-missing-local-signatures
  -fno-warn-unsafe
  -fno-warn-unused-type-patterns
  -fno-warn-identities
  -fno-warn-missing-import-lists
  -fno-warn-name-shadowing
  -fno-warn-unused-matches
  -fno-warn-unused-imports #-}

-- |  Provides generic functions for inspecting and manipulating pitch.
--
--  The pitches will usually be of type 'Pitch', as defined in "Music.Pitch.Common", but it is also
--  possible to use other types such as 'Hertz'.
module Music.Score.Pitch
  ( -- * Pitch functions

    -- ** Transposition
    up,
    down,
    above,
    below,
    octavesUp,
    octavesDown,
    _15va,
    _8va,
    _8vb,
    _15vb,
    upDiatonic,
    downDiatonic,

    -- ** Inversion
    invertPitches,
    invertDiatonic,
    invertChromatic,

    -- ** Ambitus
    pitchRange,
    highestPitch,
    lowestPitch,
    averagePitch,
    ambitusOctaves,
    ambitusLowestOctave,
    interpolateAmbitus,
    interpolateAmbitus',

    -- ** Voices
    stitch,
    stitchLast,
    stitchWith,

    -- ** Spelling
    simplifyPitches,

    -- ** Enumeration
    enumDiatonicFromTo,
    enumChromaticFromTo,
    enumDownDiatonicFromTo,
    enumDownChromaticFromTo,

    -- * Pitch type
    GetPitch,
    SetPitch,
    GetInterval,

    -- * HasPitch classes
    HasPitch (..),
    HasPitches (..),
    -- fromPitch',

    -- ** Simple versions
    HasPitch',
    HasPitches',
    pitch',
    pitches',

    -- ** Utility classes
    Transposable,
    PitchPair,
    AffinePair,
  )
where

import BasePrelude hiding ((<>))
import Control.Lens hiding (below, transform)
import Data.AffineSpace
import Data.AffineSpace.Point
import Data.AffineSpace.Point.Offsets (AffinePair)
import Data.Functor.Couple
import Data.Kind
import qualified Data.List
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Monoid.Average
import Data.Semigroup
import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Data.Set (Set)
import qualified Data.Set as Set
import Data.VectorSpace hiding (Sum)
import Music.Pitch.Absolute hiding (octaves)
import Music.Pitch.Ambitus
import Music.Pitch.Common hiding (Interval, Pitch)
import qualified Music.Pitch.Common as Common
import Music.Pitch.Literal
import Music.Score.Harmonics
import Music.Score.Part
import Music.Score.Phrases
import Music.Score.Slide
import Music.Score.Text
import Music.Score.Ties
import Music.Time.Aligned
import Music.Time.Behavior
import Music.Time.Event
import Music.Time.Internal.Transform
import Music.Time.Note
import Music.Time.Placed
import Music.Time.Score
import Music.Time.Internal.Track
import Music.Time.Voice hiding (map, traverse)

-- | A type function that returns the pitch type associated with a given type.
--
-- For simple types this is identity (they are their own pitch).
--
-- > GetPitch Pitch = Pitch
--
-- For containers this is a morhism
--
-- > GetPitch (Voice Pitch) = PitchOf Pitch = Pitch
type family GetPitch (s :: Type) :: Type

-- |
-- A type function to change the pitch type associate with a given type, where the first argument is the new pitch type,
-- and the second argument is the previous compound type.
--
-- For simple types this is constant (replacing means replacing the whole type).
--
-- > SetPitch Hertz Pitch = Hertz
--
-- For containers this is a morhism
--
-- > SetPitch Hertz (Voice Pitch) = Voice Hertz
type family SetPitch (b :: Type) (s :: Type) :: Type

-- | Types which has a single pitch (i.e notes, events, the pitches themselves).
class HasPitches s t => HasPitch s t where
  -- | Access the pitch.
  pitch :: Lens s t (GetPitch s) (GetPitch t)

-- | Types which has multiple pitches (i.e. voices, scores).
class
  ( SetPitch (GetPitch t) s ~ t
  ) =>
  HasPitches s t where
  -- | Access all pitches.
  pitches :: Traversal s t (GetPitch s) (GetPitch t)

-- |  Same as 'HasPitch' but does not allow you to change the type.
type HasPitch' a = HasPitch a a

-- |  Same as 'HasPitches' but does not allow you to change the type.
type HasPitches' a = HasPitches a a

-- |  Access the pitch. This is the same as 'pitch', but does not allow you to change the type.
pitch' :: HasPitch' s => Lens' s (GetPitch s)
pitch' = pitch

-- | Access all pitches. Same as 'pitches', but does not allow you to change the type.
pitches' :: HasPitches' s => Traversal' s (GetPitch s)
pitches' = pitches

type instance GetPitch () = ()

type instance SetPitch a () = a

instance (a ~ GetPitch a) => HasPitch () a where pitch = ($)

instance (a ~ GetPitch a) => HasPitches () a where pitches = ($)

type instance GetPitch (c, a) = GetPitch a

type instance SetPitch b (c, a) = (c, SetPitch b a)

type instance GetPitch [a] = GetPitch a

type instance SetPitch b [a] = [SetPitch b a]

type instance GetPitch (Map k a) = GetPitch a

type instance SetPitch b (Map k a) = Map k (SetPitch b a)

type instance GetPitch (Seq a) = GetPitch a

type instance SetPitch b (Seq a) = Seq (SetPitch b a)

type instance GetPitch (Maybe a) = GetPitch a

type instance SetPitch b (Maybe a) = Maybe (SetPitch b a)

type instance GetPitch (Either c a) = GetPitch a

type instance SetPitch b (Either c a) = Either c (SetPitch b a)

type instance GetPitch (Event a) = GetPitch a

type instance SetPitch b (Event a) = Event (SetPitch b a)

type instance GetPitch (Placed a) = GetPitch a

type instance SetPitch b (Placed a) = Placed (SetPitch b a)

type instance GetPitch (Note a) = GetPitch a

type instance SetPitch b (Note a) = Note (SetPitch b a)

type instance GetPitch (Voice a) = GetPitch a

type instance SetPitch b (Voice a) = Voice (SetPitch b a)

type instance GetPitch (Track a) = GetPitch a

type instance SetPitch b (Track a) = Track (SetPitch b a)

type instance GetPitch (Score a) = GetPitch a

type instance SetPitch b (Score a) = Score (SetPitch b a)

type instance GetPitch (Aligned a) = GetPitch a

type instance SetPitch b (Aligned a) = Aligned (SetPitch b a)

instance HasPitches a b => HasPitches (Aligned a) (Aligned b) where
  pitches = traverse . pitches

instance HasPitch a b => HasPitch (c, a) (c, b) where
  pitch = _2 . pitch

instance HasPitches a b => HasPitches (c, a) (c, b) where
  pitches = traverse . pitches

instance (HasPitches a b) => HasPitches (Event a) (Event b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (Event a) (Event b) where
  pitch = from event . _2 . pitch

instance (HasPitches a b) => HasPitches (Placed a) (Placed b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (Placed a) (Placed b) where
  pitch = _Wrapped . _2 . pitch

instance (HasPitches a b) => HasPitches (Note a) (Note b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (Note a) (Note b) where
  pitch = _Wrapped . _2 . pitch

instance HasPitches a b => HasPitches [a] [b] where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Seq a) (Seq b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Map k a) (Map k b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Maybe a) (Maybe b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Either c a) (Either c b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Voice a) (Voice b) where
  pitches = traverse . pitches

instance HasPitches a b => HasPitches (Track a) (Track b) where
  pitches = traverse . pitches

type instance GetPitch (NonEmpty a) = GetPitch a

type instance SetPitch b (NonEmpty a) = NonEmpty (SetPitch b a)

instance HasPitches a b => HasPitches (NonEmpty a) (NonEmpty b) where
  pitches = traverse . pitches

{-
type instance Pitch (Chord a)       = Pitch a
type instance SetPitch b (Chord a)  = Chord (SetPitch b a)
instance HasPitches a b => HasPitches (Chord a) (Chord b) where
  pitches = traverse . pitches
-}

instance (HasPitches a b) => HasPitches (Score a) (Score b) where
  pitches = traverse . pitches

type instance GetPitch (Sum a) = GetPitch a

type instance SetPitch b (Sum a) = Sum (SetPitch b a)

instance HasPitches a b => HasPitches (Sum a) (Sum b) where
  pitches = traverse . pitches

type instance GetPitch (Behavior a) = Behavior a

type instance SetPitch b (Behavior a) = b

instance (b ~ GetPitch b) => HasPitches (Behavior a) b where
  pitches = ($)

instance (b ~ GetPitch b) => HasPitch (Behavior a) b where
  pitch = ($)

type instance GetPitch (Couple c a) = GetPitch a

type instance SetPitch g (Couple c a) = Couple c (SetPitch g a)

type instance GetPitch (TextT a) = GetPitch a

type instance SetPitch g (TextT a) = TextT (SetPitch g a)

type instance GetPitch (HarmonicT a) = GetPitch a

type instance SetPitch g (HarmonicT a) = HarmonicT (SetPitch g a)

type instance GetPitch (TieT a) = GetPitch a

type instance SetPitch g (TieT a) = TieT (SetPitch g a)

type instance GetPitch (SlideT a) = GetPitch a

type instance SetPitch g (SlideT a) = SlideT (SetPitch g a)

type instance GetPitch (Ambitus v a) = GetPitch a

type instance SetPitch g (Ambitus v a) = Ambitus v (SetPitch g a)

instance (HasPitches a b) => HasPitches (Couple c a) (Couple c b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (Couple c a) (Couple c b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (TextT a) (TextT b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (TextT a) (TextT b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (HarmonicT a) (HarmonicT b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (HarmonicT a) (HarmonicT b) where
  pitch = iso getHarmonicT HarmonicT . pitch

instance (HasPitches a b) => HasPitches (TieT a) (TieT b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (TieT a) (TieT b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (SlideT a) (SlideT b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (SlideT a) (SlideT b) where
  pitch = _Wrapped . pitch

instance (HasPitches a b) => HasPitches (Ambitus v a) (Ambitus v b) where
  pitches = traverse . pitches

-- |
-- Associated interval type.
type GetInterval a = Diff (GetPitch a)

type PitchPair v w = (Num (Scalar v), IsInterval v, IsPitch w)

-- |
-- Class of types that can be transposed, inverted and so on.
type Transposable a =
  ( HasPitches' a,
    AffinePair (GetInterval a) (GetPitch a),
    PitchPair (GetInterval a) (GetPitch a)
  )

-- |
-- Transpose (translate) up.
--
-- >>> up m3 (c :: Pitch)
-- eb
--
-- >>> up _P5 [c,d,e :: Pitch]
-- [g,a,b]
up :: Transposable a => GetInterval a -> a -> a
up v = pitches %~ (.+^ v)

-- |
-- Transpose (translate) down.
--
-- >>> down m3 (c :: Pitch)
-- a
--
-- >>> down _P5 [c,d,e]
-- [f_,g_,a_]
down :: Transposable a => GetInterval a -> a -> a
down v = pitches %~ (.-^ v)

-- |
-- Add the given interval above.
--
-- >>> above _P5 [c :: Pitch]
-- [c,g]
--
-- >>> above _P5 (c :: Score Pitch)
-- [c,g]^.score
above :: (Semigroup a, Transposable a) => GetInterval a -> a -> a
above v x = x <> up v x

-- |
-- Add the given interval below.
--
-- >>> below _P8 [c :: Pitch]
-- [c,c_]
below :: (Semigroup a, Transposable a) => GetInterval a -> a -> a
below v x = x <> down v x

-- |
-- Invert pitches.
invertPitches :: Transposable a => GetPitch a -> a -> a
invertPitches p = pitches %~ reflectThrough p

-- |
-- Transpose up by the given number of octaves.
--
-- >>> octavesUp 2 (c :: Pitch)
-- c''
--
-- >>> octavesUp (-1) [c,d,e]
-- [c_,d_,e_]
octavesUp :: Transposable a => Scalar (GetInterval a) -> a -> a
octavesUp n = up (_P8 ^* n)

-- |
-- Transpose down by the given number of octaves.
--
-- >>> octavesDown 2 (c :: Pitch)
-- c__
--
-- >>> octavesDown (-1) [c,d,e]
-- [c',d',e']
octavesDown :: Transposable a => Scalar (GetInterval a) -> a -> a
octavesDown n = down (_P8 ^* n)

-- | Same as @'octavesUp' 2@.
_15va :: Transposable a => a -> a
_15va = octavesUp 2

-- | Same as @'octavesUp' 1@.
_8va :: Transposable a => a -> a
_8va = octavesUp 1

-- | Same as @'octavesDown' 1@.
_8vb :: Transposable a => a -> a
_8vb = octavesDown 1

-- | Same as @'octavesDown' 2@.
_15vb :: Transposable a => a -> a
_15vb = octavesDown 2

-- | Extract the highest pitch. Returns @Nothing@ if there are none.
--
-- >>> highestPitch [c,d,e :: Pitch]
-- Just e
--
-- >>> highestPitch (Data.Map.fromList [("do",c),("re",d)] :: Data.Map.Map String Pitch)
-- Just d
highestPitch :: (HasPitches' a, Ord (GetPitch a)) => a -> Maybe (GetPitch a)
highestPitch = maximumOf pitches'

-- | Extract the lowest pitch. Returns @Nothing@ if there are none.
--
-- >>> highestPitch [c,d,e :: Pitch]
-- Just c
--
-- >>> highestPitch (Data.Map.fromList [("do",c),("re",d)] :: Data.Map.Map String Pitch)
-- Just c
lowestPitch :: (HasPitches' a, Ord (GetPitch a)) => a -> Maybe (GetPitch a)
lowestPitch = minimumOf pitches'

pitchRange :: (HasPitches' a, Ord p, p ~ GetPitch a) => a -> Maybe (Ambitus v p)
pitchRange x = do
  lo <- lowestPitch x
  hi <- highestPitch x
  pure $ Ambitus lo hi

-- | Extract the average pitch. Returns @Nothing@ if there are none.
--
-- >>> averagePitch (Data.Map.fromList [(True,440::Hertz),(False,445)])
-- Just 442.5 Hz
averagePitch :: (HasPitches' a, Fractional (GetPitch a)) => a -> Maybe (GetPitch a)
averagePitch = maybeAverage . Average . toListOf pitches'

-- | The number of whole octaves in an ambitus.
ambitusOctaves :: Ambitus Common.Interval Common.Pitch -> Int
ambitusOctaves = fromIntegral . octaves . ambitusInterval

-- | The lowest octave (relative middle C) in present a given ambitus.
ambitusLowestOctave :: Ambitus Common.Interval Common.Pitch -> Int
ambitusLowestOctave = fromIntegral . octaves . (.-. c) . Music.Pitch.Ambitus.low

-- |  Interpolate between the highest and lowest points in an ambitus.
--
--  Can be used as a primitive contour-based melody generator.
interpolateAmbitus :: AffinePair v p => Ambitus v p -> Scalar v -> p
interpolateAmbitus a = let Ambitus m n = a in alerp m n

-- TODO move to Pitch.Ambitus!

-- |
-- Same as @interpolateAmbitus@ but allow continous interpolation of standard pitch
-- (as @Scalar (Diff Pitch) ~ Integer@).
interpolateAmbitus' :: Ambitus Double Common.Pitch -> Double -> Common.Pitch
interpolateAmbitus' a x = (^. from pitchDouble) $ interpolateAmbitus (fmap (^. pitchDouble) a) x
  where
    -- We can't interpolate an (Ambitus Pitch) using fractions because of music-pitch/issues/16
    -- Work around by converting pitches into doubles and back
    -- Use Double rather than Hertz due to the latter's suspect affine space instance
    -- Only an Iso up to enharmonic equivalence.
    pitchDouble :: Iso' Common.Pitch Double
    pitchDouble = iso (\x -> fromIntegral (semitones (x .-. c))) (\x -> c .+^ spell usingSharps (round x :: Semitones))

-- |
-- >>> enumDiatonicFromTo c c
-- [c]
-- >>> enumDiatonicFromTo f f'
-- [f,g,a,bb,c',d',e',f']
-- >>>
-- >>> enumChromaticFromTo c c'
-- [c,cs,d,ds,e,f,fs,g,gs,a,as,b,c']
-- >>>
-- >>> enumChromaticFromTo bs bs'
-- [bs,bss,css',csss',dss',es',ess',fss',fsss',gss',gsss',ass',bs']
enumDiatonicFromTo :: Common.Pitch -> Common.Pitch -> [Common.Pitch]
enumDiatonicFromTo x y = takeWhile (<= y) $ fmap (\n -> upDiatonic x n x) [0 ..]

-- |
enumChromaticFromTo :: Common.Pitch -> Common.Pitch -> [Common.Pitch]
enumChromaticFromTo x y = takeWhile (<= y) $ fmap (\n -> upChromatic x n x) [0 ..]

-- |
enumDownDiatonicFromTo :: Common.Pitch -> Common.Pitch -> [Common.Pitch]
enumDownDiatonicFromTo x y = takeWhile (>= y) $ fmap (\n -> downDiatonic x n x) [0 ..]

-- |
enumDownChromaticFromTo :: Common.Pitch -> Common.Pitch -> [Common.Pitch]
enumDownChromaticFromTo x y = takeWhile (>= y) $ fmap (\n -> downChromatic x n x) [0 ..]

-- | Diatonic transposition, using the diatonic scale centered around the given note.
--
-- >>> upDiatonic c 1 (e :: Pitch)
-- f
-- >>> upDiatonic g 1 (e :: Pitch)
-- fs
-- >>> upDiatonic c 2 [e,f,g :: Pitch]
-- [g,a,b]
-- >>> upDiatonic f 2 [e,f,g :: Pitch]
-- [g,a,bb]
upDiatonic ::
  (HasPitches' a, GetPitch a ~ Common.Pitch) =>
  -- | Tonic
  Common.Pitch ->
  -- | Number of steps to transpose
  DiatonicSteps ->
  -- | Original music
  a ->
  a
upDiatonic o n = over pitches' (upDiatonicP o n)

-- | Diatonic transposition, using the diatonic scale centered around the given note.
--
-- >>> upDiatonic c 1 (e :: Pitch)
-- f
-- >>> upDiatonic g 1 (e :: Pitch)
-- fs
-- >>> upDiatonic c 2 [e,f,g :: Pitch]
-- [g,a,b]
-- >>> upDiatonic f 2 [e,f,g :: Pitch]
-- [g,a,bb]
downDiatonic ::
  (HasPitches' a, GetPitch a ~ Common.Pitch) =>
  -- | Tonic
  Common.Pitch ->
  -- | Number of steps to transpose
  DiatonicSteps ->
  -- | Original music
  a ->
  a
downDiatonic o n = over pitches' (downDiatonicP o n)

-- | Chromatic transposition, using the diatonic scale centered around the given note.
--
-- >>> upDiatonic c 1 (e :: Pitch)
-- f
-- >>> upDiatonic g 1 (e :: Pitch)
-- fs
-- >>> upDiatonic c 2 [e,f,g :: Pitch]
-- [g,a,b]
-- >>> upDiatonic f 2 [e,f,g :: Pitch]
-- [g,a,bb]
upChromatic ::
  (HasPitches' a, GetPitch a ~ Common.Pitch) =>
  -- | Tonic
  Common.Pitch ->
  -- | Number of steps to transpose
  ChromaticSteps ->
  -- | Original music
  a ->
  a
upChromatic o n = over pitches' (upChromaticP' o n)

-- | Chromatic transposition, using the diatonic scale centered around the given note.
--
-- >>> upDiatonic c 1 (e :: Pitch)
-- f
-- >>> upDiatonic g 1 (e :: Pitch)
-- fs
-- >>> upDiatonic c 2 [e,f,g :: Pitch]
-- [g,a,b]
-- >>> upDiatonic f 2 [e,f,g :: Pitch]
-- [g,a,bb]
downChromatic ::
  (HasPitches' a, GetPitch a ~ Common.Pitch) =>
  -- | Tonic
  Common.Pitch ->
  -- | Number of steps to transpose
  ChromaticSteps ->
  -- | Original music
  a ->
  a
downChromatic o n = over pitches' (downChromaticP' o n)

-- |
-- >>> invertDiatonic c ([e,gs]^.score :: Score Pitch)
-- [(0 <-> 1,a_)^.event,(0 <-> 1,fs_)^.event]^.score
invertDiatonic ::
  (HasPitches' a, GetPitch a ~ Common.Pitch) =>
  -- | Tonic
  Common.Pitch ->
  -- | Original music
  a ->
  a
invertDiatonic o = over pitches' (invertDiatonicallyP o)

-- |
-- >>> invertChromatic c ([e,gs]^.score :: Score Pitch)
-- [(0 <-> 1,e)^.event,(0 <-> 1,gb)^.event]^.score
invertChromatic ::
  (HasPitches' a, GetPitch a ~ Common.Pitch) =>
  -- | Tonic
  Common.Pitch ->
  -- | Original music
  a ->
  a
invertChromatic o = over pitches' (invertChromaticallyP o)

downChromaticP' :: Common.Pitch -> ChromaticSteps -> Common.Pitch -> Common.Pitch
downChromaticP' o n = upChromaticP' o (- n)

upChromaticP' :: Common.Pitch -> ChromaticSteps -> Common.Pitch -> Common.Pitch
upChromaticP' _ n p
  | n >= 0 = p .+^ spell usingSharps (fromIntegral n :: Semitones)
  | n < 0 = p .-^ spell usingFlats (fromIntegral (abs n) :: Semitones)
  | otherwise = error "Impossible"

-- | Simpify the spelling of each pitch.
simplifyPitches :: (HasPitches' a, GetPitch a ~ Common.Pitch) => a -> a
simplifyPitches = over pitches' simplifyPitch
  where
    simplifyPitch p
      | accidental p < doubleFlat = relative c (spell usingFlats) p
      | accidental p > doubleSharp = relative c (spell usingSharps) p
      | otherwise = p

-- |
-- Join two voices together so that one note overlaps. The second voice is
-- transposed to achieve this.
--
-- At the join point the note from the first voice is used. If @a ~ GetPitch@,
-- then 'stitch' and 'stitchLast' are equivalent.
--
-- >>> stitch ([c :: Note GetPitch,d,e]^.voice) ([c,g]^.voice)
-- [(1,c)^.note,(1,d)^.note,(1,e)^.note,(1,b)^.note]^.voice
stitch :: (Transposable a) => Voice a -> Voice a -> Voice a
stitch = stitchWith (\a b -> [a] ^. voice)

-- Join two voices together so that one note overlaps. The second voice is
-- transposed to achieve this.
--
-- At the join point the note from the first voice is used. If @a ~ GetPitch@,
-- then 'stitch' and 'stitchLast' are equivalent.
--
-- At the join point the note from the second voice is used.
stitchLast :: (Transposable a) => Voice a -> Voice a -> Voice a
stitchLast = stitchWith (\a b -> [b] ^. voice)

stitchWith ::
  forall a.
  (Transposable a) =>
  (Note a -> Note a -> Voice a) ->
  Voice a ->
  Voice a ->
  Voice a
stitchWith f a b
  | nullOf notes a = b
  | nullOf notes b = a
  | otherwise = initV a <> f (lastV a) (headV (up diff b)) <> tailV (up diff b)
  where
    headV = (^?! notes . _head)
    lastV = (^?! notes . _last)
    initV = over notes init
    tailV = over notes tail
    lastPitch a = lastV a ^?! pitches
    headPitch b = headV b ^?! pitches
    diff = lastPitch a .-. headPitch b

type instance GetPitch Common.Pitch = Common.Pitch

type instance SetPitch a Common.Pitch = a

instance (a ~ GetPitch a) => HasPitch Common.Pitch a where
  pitch = ($)

instance (a ~ GetPitch a) => HasPitches Common.Pitch a where
  pitches = ($)

type instance GetPitch Hertz = Hertz

type instance SetPitch a Hertz = a

instance (a ~ GetPitch a) => HasPitch Hertz a where
  pitch = ($)

instance (a ~ GetPitch a) => HasPitches Hertz a where
  pitches = ($)
