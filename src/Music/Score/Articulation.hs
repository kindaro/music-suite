{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC
  -fno-warn-name-shadowing
  -fno-warn-unused-imports
  -fno-warn-redundant-constraints #-}

-- |  Provides functions for manipulating articulation.
module Music.Score.Articulation
  ( -- ** Articulation type functions
    GetArticulation,
    SetArticulation,
    Accentuation,
    Separation,
    Articulated (..),

    -- ** Accessing articulation
    HasArticulations (..),
    HasArticulation (..),
    HasArticulations',
    HasArticulation',
    articulation',
    articulations',

    -- * Manipulating articulation

    -- ** Accents
    accent,
    marcato,
    accentLast,
    marcatoLast,
    accentAll,
    marcatoAll,

    -- ** Phrasing and separation
    staccatissimo,
    staccato,
    separated,
    portato,
    legato,
    legatissimo,

    -- * Articulation transformer
    ArticulationT (..),

    -- * Context
    varticulation,
    addArtCon,
  )
where

import BasePrelude hiding ((<>), Dynamic, first, second)
import Control.Comonad
import Control.Lens hiding ((&), below, transform)
import Data.AffineSpace
import Data.Functor.Context
import Data.Functor.Couple
import Data.Kind
import Data.Semigroup
import Data.VectorSpace hiding (Sum)
import Music.Dynamics.Literal
import Music.Pitch.Literal
import Music.Score.Harmonics
import Music.Score.Part
import Music.Score.Phrases
import Music.Score.Slide
import Music.Score.Text
import Music.Score.Ties
import Music.Time.Voice
import Music.Time.Score
import Music.Time.Track
import Music.Time.Note
import Music.Time.Placed
import Music.Time.Event
import Music.Time.Internal.Transform

-- |
-- Articulations type.
type family GetArticulation (s :: Type) :: Type

-- |
-- Articulation type.
type family SetArticulation (b :: Type) (s :: Type) :: Type

type ArticulationLensLaws' s t a b =
  ( GetArticulation (SetArticulation a s) ~ a,
    SetArticulation (GetArticulation t) s ~ t,
    SetArticulation a (SetArticulation b s) ~ SetArticulation a s
  )

type ArticulationLensLaws s t = ArticulationLensLaws' s t (GetArticulation s) (GetArticulation t)

-- |
-- Class of types that provide a single articulation.
class (HasArticulations s t) => HasArticulation s t where
  -- | Articulation type.
  articulation :: Lens s t (GetArticulation s) (GetArticulation t)

-- |
-- Class of types that provide a articulation traversal.
class
  ( ArticulationLensLaws s t
  ) =>
  HasArticulations s t where
  -- | Articulation type.
  articulations :: Traversal s t (GetArticulation s) (GetArticulation t)

type HasArticulation' a = HasArticulation a a

type HasArticulations' a = HasArticulations a a

-- |
-- Articulation type.
articulation' :: (HasArticulation s t, s ~ t) => Lens' s (GetArticulation s)
articulation' = articulation

-- |
-- Articulation type.
articulations' :: (HasArticulations s t, s ~ t) => Traversal' s (GetArticulation s)
articulations' = articulations

type instance GetArticulation (c, a) = GetArticulation a

type instance SetArticulation b (c, a) = (c, SetArticulation b a)

type instance GetArticulation [a] = GetArticulation a

type instance SetArticulation b [a] = [SetArticulation b a]

type instance GetArticulation (Maybe a) = GetArticulation a

type instance SetArticulation b (Maybe a) = Maybe (SetArticulation b a)

type instance GetArticulation (Either c a) = GetArticulation a

type instance SetArticulation b (Either c a) = Either c (SetArticulation b a)

type instance GetArticulation (Event a) = GetArticulation a

type instance SetArticulation g (Event a) = Event (SetArticulation g a)

type instance GetArticulation (Placed a) = GetArticulation a

type instance SetArticulation g (Placed a) = Placed (SetArticulation g a)

type instance GetArticulation (Note a) = GetArticulation a

type instance SetArticulation g (Note a) = Note (SetArticulation g a)

type instance GetArticulation (Voice a) = GetArticulation a

type instance SetArticulation b (Voice a) = Voice (SetArticulation b a)

type instance GetArticulation (Track a) = GetArticulation a

type instance SetArticulation b (Track a) = Track (SetArticulation b a)

type instance GetArticulation (Score a) = GetArticulation a

type instance SetArticulation b (Score a) = Score (SetArticulation b a)

instance HasArticulation a b => HasArticulation (c, a) (c, b) where
  articulation = _2 . articulation

instance HasArticulations a b => HasArticulations (c, a) (c, b) where
  articulations = traverse . articulations

instance HasArticulations a b => HasArticulations [a] [b] where
  articulations = traverse . articulations

instance HasArticulations a b => HasArticulations (Maybe a) (Maybe b) where
  articulations = traverse . articulations

instance HasArticulations a b => HasArticulations (Either c a) (Either c b) where
  articulations = traverse . articulations

instance (HasArticulations a b) => HasArticulations (Event a) (Event b) where
  articulations = traverse . articulations

instance (HasArticulation a b) => HasArticulation (Event a) (Event b) where
  articulation = from event . _2 . articulation

instance (HasArticulations a b) => HasArticulations (Placed a) (Placed b) where
  articulations = traverse . articulations

instance (HasArticulation a b) => HasArticulation (Placed a) (Placed b) where
  articulation = from placed . _2 . articulation

instance (HasArticulations a b) => HasArticulations (Note a) (Note b) where
  articulations = traverse . articulations

instance (HasArticulation a b) => HasArticulation (Note a) (Note b) where
  articulation = from note . _2 . articulation

instance HasArticulations a b => HasArticulations (Voice a) (Voice b) where
  articulations = traverse . articulations

instance HasArticulations a b => HasArticulations (Track a) (Track b) where
  articulations = traverse . articulations

instance HasArticulations a b => HasArticulations (Score a) (Score b) where
  articulations = traverse . articulations

type instance GetArticulation (Couple c a) = GetArticulation a

type instance SetArticulation g (Couple c a) = Couple c (SetArticulation g a)

type instance GetArticulation (TextT a) = GetArticulation a

type instance SetArticulation g (TextT a) = TextT (SetArticulation g a)

type instance GetArticulation (HarmonicT a) = GetArticulation a

type instance SetArticulation g (HarmonicT a) = HarmonicT (SetArticulation g a)

type instance GetArticulation (TieT a) = GetArticulation a

type instance SetArticulation g (TieT a) = TieT (SetArticulation g a)

type instance GetArticulation (SlideT a) = GetArticulation a

type instance SetArticulation g (SlideT a) = SlideT (SetArticulation g a)

instance (HasArticulations a b) => HasArticulations (Couple c a) (Couple c b) where
  articulations = _Wrapped . articulations

instance (HasArticulation a b) => HasArticulation (Couple c a) (Couple c b) where
  articulation = _Wrapped . articulation

instance (HasArticulations a b) => HasArticulations (TextT a) (TextT b) where
  articulations = _Wrapped . articulations

instance (HasArticulation a b) => HasArticulation (TextT a) (TextT b) where
  articulation = _Wrapped . articulation

instance (HasArticulations a b) => HasArticulations (HarmonicT a) (HarmonicT b) where
  articulations = traverse . articulations

instance (HasArticulation a b) => HasArticulation (HarmonicT a) (HarmonicT b) where
  articulation = iso getHarmonicT HarmonicT . articulation

instance (HasArticulations a b) => HasArticulations (TieT a) (TieT b) where
  articulations = _Wrapped . articulations

instance (HasArticulation a b) => HasArticulation (TieT a) (TieT b) where
  articulation = _Wrapped . articulation

instance (HasArticulations a b) => HasArticulations (SlideT a) (SlideT b) where
  articulations = _Wrapped . articulations

instance (HasArticulation a b) => HasArticulation (SlideT a) (SlideT b) where
  articulation = _Wrapped . articulation

type family Accentuation (a :: Type) :: Type

type family Separation (a :: Type) :: Type

type instance Accentuation () = ()

type instance Separation () = ()

type instance Accentuation (a, b) = a

type instance Separation (a, b) = b

-- |
-- Class of types that can be transposed, inverted and so on.
class
  ( Fractional (Accentuation a),
    Fractional (Separation a),
    AffineSpace (Accentuation a),
    AffineSpace (Separation a)
  ) =>
  Articulated a where

  accentuation :: Lens' a (Accentuation a)

  separation :: Lens' a (Separation a)

instance (AffineSpace a, AffineSpace b, Fractional a, Fractional b) => Articulated (a, b) where

  accentuation = _1

  separation = _2

accent :: (HasPhrases' s b, HasArticulations' b, GetArticulation b ~ a, Articulated a) => s -> s
accent = set (phrases . _head . articulations . accentuation) 1

marcato :: (HasPhrases' s b, HasArticulations' b, GetArticulation b ~ a, Articulated a) => s -> s
marcato = set (phrases . _head . articulations . accentuation) 2

accentLast :: (HasPhrases' s b, HasArticulations' b, GetArticulation b ~ a, Articulated a) => s -> s
accentLast = set (phrases . _last . articulations . accentuation) 1

marcatoLast :: (HasPhrases' s b, HasArticulations' b, GetArticulation b ~ a, Articulated a) => s -> s
marcatoLast = set (phrases . _last . articulations . accentuation) 2

accentAll :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
accentAll = set (articulations . accentuation) 1

marcatoAll :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
marcatoAll = set (articulations . accentuation) 2

legatissimo :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
legatissimo = set (articulations . separation) (-2)

legato :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
legato = set (articulations . separation) (-1)

separated :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
separated = set (articulations . separation) 0

portato :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
portato = set (articulations . separation) 0.5

staccato :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
staccato = set (articulations . separation) 1

staccatissimo :: (HasArticulations' s, GetArticulation s ~ a, Articulated a) => s -> s
staccatissimo = set (articulations . separation) 2

newtype ArticulationT n a = ArticulationT {getArticulationT :: (n, a)}
  deriving
    ( Eq,
      Ord,
      Show,
      Typeable,
      Functor,
      Applicative,
      Monad,
      Comonad,
      Transformable,
      Monoid,
      Semigroup
    )

instance (Monoid n, Num a) => Num (ArticulationT n a) where

  (+) = liftA2 (+)

  (*) = liftA2 (*)

  (-) = liftA2 (-)

  abs = fmap abs

  signum = fmap signum

  fromInteger = pure . fromInteger

instance (Monoid n, Fractional a) => Fractional (ArticulationT n a) where

  recip = fmap recip

  fromRational = pure . fromRational

instance (Monoid n, Floating a) => Floating (ArticulationT n a) where

  pi = pure pi

  sqrt = fmap sqrt

  exp = fmap exp

  log = fmap log

  sin = fmap sin

  cos = fmap cos

  asin = fmap asin

  atan = fmap atan

  acos = fmap acos

  sinh = fmap sinh

  cosh = fmap cosh

  asinh = fmap asinh

  atanh = fmap atanh

  acosh = fmap acos

instance (Monoid n, Enum a) => Enum (ArticulationT n a) where

  toEnum = pure . toEnum

  fromEnum = fromEnum . extract

instance (Monoid n, Bounded a) => Bounded (ArticulationT n a) where

  minBound = pure minBound

  maxBound = pure maxBound

instance Wrapped (ArticulationT p a) where

  type Unwrapped (ArticulationT p a) = (p, a)

  _Wrapped' = iso getArticulationT ArticulationT

instance Rewrapped (ArticulationT p a) (ArticulationT p' b)

type instance GetArticulation (ArticulationT p a) = p

type instance SetArticulation p' (ArticulationT p a) = ArticulationT p' a

instance HasArticulation (ArticulationT p a) (ArticulationT p' a) where
  articulation = _Wrapped . _1

instance HasArticulations (ArticulationT p a) (ArticulationT p' a) where
  articulations = _Wrapped . _1

deriving instance (IsPitch a, Monoid n) => IsPitch (ArticulationT n a)

deriving instance (IsInterval a, Monoid n) => IsInterval (ArticulationT n a)

instance (Tiable n, Tiable a) => Tiable (ArticulationT n a) where
  toTied (ArticulationT (d, a)) = (ArticulationT (d1, a1), ArticulationT (d2, a2))
    where
      (a1, a2) = toTied a
      (d1, d2) = toTied d

addArtCon ::
  ( HasPhrases s t a b,
    HasArticulation' a,
    HasArticulation a b,
    GetArticulation a ~ d,
    GetArticulation b ~ Ctxt d
  ) =>
  s ->
  t
addArtCon = over (phrases . varticulation) withContext

varticulation ::
  (HasArticulation s s, HasArticulation s t) =>
  Lens (Voice s) (Voice t) (Voice (GetArticulation s)) (Voice (GetArticulation t))
varticulation = lens (fmap $ view articulation) (flip $ zipVoiceWithNoScale (set articulation))
