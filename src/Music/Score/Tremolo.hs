{-# LANGUAGE DefaultSignatures #-}

module Music.Score.Tremolo
  ( -- * Tremolo
    HasTremolo (..),
    tremolo,

    -- ** Tremolo note transformer
    TremoloT (..),
    mapTremoloT,
    runTremoloT,
  )
where

import Control.Comonad
import Data.Functor.Couple
import Data.Semigroup
import Data.Typeable
import Music.Dynamics.Literal
import Music.Pitch.Alterable
import Music.Pitch.Augmentable
import Music.Pitch.Literal
import Music.Score.Articulation
import Music.Score.Dynamics
import Music.Score.Harmonics
import Music.Score.Pitch
import Music.Score.Slide
import Music.Score.Text
import Music.Score.Ties
import Music.Time

-- |
-- Class of types with a notion of tremolo.
--
-- ==== Laws
--
-- [/set-set/]
--
--    @'setTrem' n ('setTrem' m x) = 'setTrem' n x@
class HasTremolo a where

  setTrem :: Int -> a -> a

  default setTrem :: forall f b. (a ~ f b, Functor f, HasTremolo b) => Int -> a -> a
  setTrem s = fmap (setTrem s)

instance HasTremolo a => HasTremolo (Maybe a)

instance HasTremolo a => HasTremolo (b, a)

instance HasTremolo a => HasTremolo (Couple b a)

instance HasTremolo a => HasTremolo [a]

instance HasTremolo a => HasTremolo (Score a)

-- |
-- Set the number of tremolo divisions for all notes in the score.
tremolo :: HasTremolo a => Int -> a -> a
tremolo = setTrem

newtype TremoloT a = TremoloT {getTremoloT :: Couple (Max Word) a}
  deriving (Eq, Show, Ord, Functor, Foldable, Traversable, Typeable, Applicative, Monad, Comonad)

--
-- We use Word instead of Int to get (mempty = Max 0), as (Max.mempty = Max minBound)
-- Preferably we would use Natural but unfortunately this is not an instance of Bounded
--

instance HasTremolo (TremoloT a) where
  setTrem n (TremoloT (Couple (_, a))) = TremoloT (Couple (fromIntegral n, a))

deriving instance Num a => Num (TremoloT a)

deriving instance Fractional a => Fractional (TremoloT a)

deriving instance Floating a => Floating (TremoloT a)

deriving instance Enum a => Enum (TremoloT a)

deriving instance Bounded a => Bounded (TremoloT a)

deriving instance (Num a, Ord a, Real a) => Real (TremoloT a)

deriving instance (Real a, Enum a, Integral a) => Integral (TremoloT a)

deriving instance IsPitch a => IsPitch (TremoloT a)

deriving instance IsDynamics a => IsDynamics (TremoloT a)

deriving instance Semigroup a => Semigroup (TremoloT a)

deriving instance Tiable a => Tiable (TremoloT a)

deriving instance HasHarmonic a => HasHarmonic (TremoloT a)

deriving instance HasSlide a => HasSlide (TremoloT a)

deriving instance HasText a => HasText (TremoloT a)

deriving instance Transformable a => Transformable (TremoloT a)

deriving instance Alterable a => Alterable (TremoloT a)

deriving instance Augmentable a => Augmentable (TremoloT a)

type instance GetPitch (TremoloT a) = GetPitch a

type instance SetPitch g (TremoloT a) = TremoloT (SetPitch g a)

type instance GetDynamic (TremoloT a) = GetDynamic a

type instance SetDynamic g (TremoloT a) = TremoloT (SetDynamic g a)

type instance GetArticulation (TremoloT a) = GetArticulation a

type instance SetArticulation g (TremoloT a) = TremoloT (SetArticulation g a)

instance (HasPitches a b) => HasPitches (TremoloT a) (TremoloT b) where
  pitches = traverse . pitches

instance (HasPitch a b) => HasPitch (TremoloT a) (TremoloT b) where
  pitch = mapTremoloT . pitch

instance (HasDynamics a b) => HasDynamics (TremoloT a) (TremoloT b) where
  dynamics = traverse . dynamics

instance (HasDynamic a b) => HasDynamic (TremoloT a) (TremoloT b) where
  dynamic = mapTremoloT . dynamic

instance (HasArticulations a b) => HasArticulations (TremoloT a) (TremoloT b) where
  articulations = traverse . articulations

instance (HasArticulation a b) => HasArticulation (TremoloT a) (TremoloT b) where
  articulation = mapTremoloT . articulation

-- | Map over a 'TremoloT' using a 'Functor'.
--
-- This function is a 'Lens'.
mapTremoloT :: Functor f => (a -> f b) -> TremoloT a -> f (TremoloT b)
mapTremoloT f (TremoloT (Couple (n, a))) = fmap (\x -> TremoloT (Couple (n, x))) (f a)

-- |
-- Get the number of tremolo divisions.
runTremoloT :: TremoloT a -> (Int, a)
runTremoloT (TremoloT (Couple (Max n, a))) = (fromIntegral n, a)
