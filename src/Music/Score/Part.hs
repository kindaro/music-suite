{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# OPTIONS_GHC
  -fno-warn-name-shadowing
  -fno-warn-unused-imports
  -fno-warn-redundant-constraints #-}

-- | Provides functions for manipulating parts.
module Music.Score.Part
  ( -- ** Part type functions
    GetPart,
    SetPart,

    -- ** Accessing parts
    HasParts (..),
    HasPart (..),
    HasPart',
    HasParts',
    part',
    parts',

    -- * Listing parts
    allParts,
    replaceParts,
    arrangeFor,

    -- * Extracting parts
    extracted,
    extractedWithInfo,
    extractPart,
    extractParts,
    extractPartsWithInfo,

    -- * Manipulating parts

    -- * Part representation
    PartT (..),

    -- * Part composition
    (</>),
    rcat,
  )
where

import BasePrelude hiding ((<>), Dynamic, first, second)
import Control.Comonad
import Control.Lens hiding ((&), parts, transform)
import Data.Functor.Couple
import Data.Kind
import qualified Data.List as List
import qualified Data.Maybe
import Data.Ord (comparing)
import Data.Semigroup
import Music.Dynamics.Literal
import Music.Parts.Subpart (BoundIncr (..), HasSubpart (..))
import Music.Pitch.Literal
import Music.Score.Internal.Util (through)
import Music.Score.Ties
import Music.Time.Aligned
import Music.Time.Event
import Music.Time.Internal.Transform
import Music.Time.Note
import Music.Time.Score
import Music.Time.Voice

-- |
-- Parts type.
type family GetPart (s :: Type) :: Type -- Part s   = a

-- |
-- Part type.
type family SetPart (b :: Type) (s :: Type) :: Type -- Part b s = t

-- |
-- Class of types that provide a single part.
class (HasParts s t) => HasPart s t where
  -- | Part type.
  part :: Lens s t (GetPart s) (GetPart t)

-- |
-- Class of types that provide a part traversal.
class HasParts s t where
  -- | Part type.
  parts :: Traversal s t (GetPart s) (GetPart t)

type HasPart' a = HasPart a a

type HasParts' a = HasParts a a

-- |
-- Part type.
part' :: (HasPart s t, s ~ t) => Lens' s (GetPart s)
part' = part

-- |
-- Part type.
parts' :: (HasParts s t, s ~ t) => Traversal' s (GetPart s)
parts' = parts

type instance GetPart Bool = Bool

type instance SetPart a Bool = a

instance (b ~ GetPart b) => HasPart Bool b where
  part = ($)

instance (b ~ GetPart b) => HasParts Bool b where
  parts = ($)

type instance GetPart Ordering = Ordering

type instance SetPart a Ordering = a

instance (b ~ GetPart b) => HasPart Ordering b where
  part = ($)

instance (b ~ GetPart b) => HasParts Ordering b where
  parts = ($)

type instance GetPart () = ()

type instance SetPart a () = a

instance (b ~ GetPart b) => HasPart () b where
  part = ($)

instance (b ~ GetPart b) => HasParts () b where
  parts = ($)

type instance GetPart Int = Int

type instance SetPart a Int = a

instance HasPart Int Int where
  part = ($)

instance HasParts Int Int where
  parts = ($)

type instance GetPart Integer = Integer

type instance SetPart a Integer = a

instance HasPart Integer Integer where
  part = ($)

instance HasParts Integer Integer where
  parts = ($)

type instance GetPart Float = Float

type instance SetPart a Float = a

instance HasPart Float Float where
  part = ($)

instance HasParts Float Float where
  parts = ($)

type instance GetPart (c, a) = GetPart a

type instance SetPart b (c, a) = (c, SetPart b a)

type instance GetPart [a] = GetPart a

type instance SetPart b [a] = [SetPart b a]

type instance GetPart (Maybe a) = GetPart a

type instance SetPart b (Maybe a) = Maybe (SetPart b a)

type instance GetPart (Either c a) = GetPart a

type instance SetPart b (Either c a) = Either c (SetPart b a)

type instance GetPart (Aligned a) = GetPart a

type instance SetPart b (Aligned a) = Aligned (SetPart b a)

instance HasParts a b => HasParts (Aligned a) (Aligned b) where
  parts = traverse . parts

instance HasPart a b => HasPart (c, a) (c, b) where
  part = _2 . part

instance HasParts a b => HasParts (c, a) (c, b) where
  parts = traverse . parts

instance HasParts a b => HasParts [a] [b] where
  parts = traverse . parts

instance HasParts a b => HasParts (Maybe a) (Maybe b) where
  parts = traverse . parts

instance HasParts a b => HasParts (Either c a) (Either c b) where
  parts = traverse . parts

type instance GetPart (Event a) = GetPart a

type instance SetPart g (Event a) = Event (SetPart g a)

instance (HasPart a b) => HasPart (Event a) (Event b) where
  part = from event . _2 . part

instance (HasParts a b) => HasParts (Event a) (Event b) where
  parts = traverse . parts

type instance GetPart (Note a) = GetPart a

type instance SetPart g (Note a) = Note (SetPart g a)

instance (HasPart a b) => HasPart (Note a) (Note b) where
  part = from note . _2 . part

instance (HasParts a b) => HasParts (Note a) (Note b) where
  parts = traverse . parts

-- |
-- List all the parts
allParts :: (Ord (GetPart a), HasParts' a) => a -> [GetPart a]
allParts = List.nub . List.sort . toListOf parts

replaceParts :: (HasParts' a, Eq (GetPart a)) => [(GetPart a, GetPart a)] -> a -> a
replaceParts xs = over parts' (`lookupPos` xs)
  where
    lookupPos x ys = Data.Maybe.fromMaybe x $ lookup x ys

arrangeFor :: (HasParts' a, Ord (GetPart a)) => [GetPart a] -> a -> a
arrangeFor ps x = replaceParts (zip (allParts x) (cycle ps)) x

-- |
-- List all the parts
extractPart :: (Eq (GetPart a), HasParts' a) => GetPart a -> Score a -> Score a
extractPart = extractPartG

extractPartG :: (Eq (GetPart a), MonadPlus f, HasParts' a) => GetPart a -> f a -> f a
extractPartG p x = head $ (\p s -> filterPart (== p) s) <$> [p] <*> return x

-- |
-- List all the parts
extractParts :: (Ord (GetPart a), HasParts' a) => Score a -> [Score a]
extractParts = extractPartsG

extractPartsG ::
  ( MonadPlus f,
    HasParts' (f a),
    HasParts' a,
    GetPart (f a) ~ GetPart a,
    Ord (GetPart a)
  ) =>
  f a ->
  [f a]
extractPartsG x =
  (\p s -> filterPart (== p) s) <$> allParts x <*> return x

filterPart :: (MonadPlus f, HasParts' a) => (GetPart a -> Bool) -> f a -> f a
filterPart p = mfilter (\x -> let ps = toListOf parts x in all p ps && not (null ps))

extractPartsWithInfo :: (Ord (GetPart a), HasPart' a) => Score a -> [(GetPart a, Score a)]
extractPartsWithInfo x = zip (allParts x) (extractParts x)

extracted :: (Ord (GetPart a), HasParts' a) => Iso (Score a) (Score b) [Score a] [Score b]
extracted = iso extractParts mconcat

extractedWithInfo :: (Ord (GetPart a), HasPart' a, HasPart' b) => Iso (Score a) (Score b) [(GetPart a, Score a)] [(GetPart b, Score b)]
extractedWithInfo = iso extractPartsWithInfo $ mconcat . fmap (uncurry $ set parts')

newtype PartT n a = PartT {getPartT :: (n, a)}
  deriving
    ( Eq,
      Ord,
      Show,
      Typeable,
      Functor,
      Foldable,
      Traversable,
      Applicative,
      Comonad,
      Monad,
      Transformable
    )

instance Wrapped (PartT p a) where

  type Unwrapped (PartT p a) = (p, a)

  _Wrapped' = iso getPartT PartT

instance Rewrapped (PartT p a) (PartT p' b)

type instance GetPart (PartT p a) = p

type instance SetPart p' (PartT p a) = PartT p' a

instance HasPart (PartT p a) (PartT p' a) where
  part = _Wrapped . _1

instance HasParts (PartT p a) (PartT p' a) where
  parts = _Wrapped . _1

instance (IsPitch a, Monoid n) => IsPitch (PartT n a) where
  fromPitch l = PartT (mempty, fromPitch l)

instance (IsDynamics a, Monoid n) => IsDynamics (PartT n a) where
  fromDynamics l = PartT (mempty, fromDynamics l)

instance Tiable a => Tiable (PartT n a) where
  toTied (PartT (v, a)) = (PartT (v, b), PartT (v, c)) where (b, c) = toTied a

type instance GetPart (Score a) = GetPart a

type instance SetPart g (Score a) = Score (SetPart g a)

instance (HasParts a b) => HasParts (Score a) (Score b) where
  parts = traverse . parts

type instance GetPart (Voice a) = GetPart a

type instance SetPart g (Voice a) = Voice (SetPart g a)

instance (HasParts a b) => HasParts (Voice a) (Voice b) where
  parts = traverse . parts

infixl 5 </>

-- |
-- Concatenate parts.
rcat :: (Monoid a, HasParts' a, HasSubpart (GetPart a)) => [a] -> a
rcat = List.foldl (</>) mempty

(</>) :: forall a. (Semigroup a, HasParts' a, HasSubpart (GetPart a)) => a -> a -> a
a </> b = a <> next b
  where
    subparts :: [SubpartOf (GetPart a)]
    subparts = toListOf (parts . subpart) a
    next :: a -> a
    next = case subparts of
      [] -> id
      (x : xs) -> set (parts . subpart) (increment' (maximum' (x :| xs)))
