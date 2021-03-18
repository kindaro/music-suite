{-# OPTIONS_GHC
  -fno-warn-unused-imports
  #-}

module Music.Time.Note
  ( -- * Note type
    Note,

    -- * Construction
    note,
    notee,
    durationNote,
  )
where

import Control.Applicative
import Control.Comonad
import Control.Lens hiding
  ( (<|),
    Indexable,
    Level,
    below,
    index,
    inside,
    parts,
    reversed,
    transform,
    (|>),
  )
import Data.Aeson (FromJSON (..), ToJSON (..))
import qualified Data.Aeson as JSON
import Data.Bifunctor
import Data.Foldable (Foldable)
import qualified Data.Foldable as Foldable
import Data.Functor.Couple
import Data.String
import Data.Typeable
import Data.VectorSpace
import Music.Dynamics.Literal
import Music.Pitch.Literal
import Music.Time.Internal.Util (dependingOn)
import Music.Time.Juxtapose

-- |
-- A value 'Note' value, representing a value stretched by some 'Duration'.
newtype Note a = Note {getNote :: Duration `Couple` a}
  deriving
    ( Eq,
      Ord,
      Typeable,
      Foldable,
      Traversable,
      Functor,
      Applicative,
      Monad,
      Comonad,
      Num,
      Fractional,
      Floating,
      Real,
      RealFrac
    )

instance (Show a) => Show (Note a) where
  show x = show (x ^. from note) ++ "^.note"

instance Wrapped (Note a) where

  type Unwrapped (Note a) = (Duration, a)

  _Wrapped' = iso (getCouple . getNote) (Note . Couple)

instance Rewrapped (Note a) (Note b)

instance Transformable (Note a) where
  transform t = over (from note . _1) (transform t)

instance HasDuration (Note a) where
  _duration = fst . view (from note)

{-
  Splitting a note is surprisingly difficult because of the recursive nature of split.

  In brief, when splitting (d,(x,a)^.note)^.note at t, we have to split the inner value x at (t/d),
  and then scale the results xa and xb by some values p and q such that the duration of the new
  nested notes (da*xa) and (db*xb) is the duration of the original nested note (d*x), as stated
  by the Splittable laws.

  Full derivation below.

  -----

  split t d = (da+db)
  split (t/d) x = (xa*p+xb*q)
  split t (d*x) = (da*xa+db*xb)

  d = da+db         [split laws]
  x = (xa*p+xb*q)   [split laws]
  d*x = da*xa+db*xb [split laws]

  Isolate p and q!

  xa*p + xb*q = x
  xa*p = x - xb*q
  p = (x - xb*q)/xa

  xa*p + xb*q = x
  xb*q = x - xa*p
  q = (x - xa*p)/xb

  -- Assuming we know t, d, x, xa*p, xb*q, da*xa, db*xb
  xa = da*xa/da
  xb = db*xb/db

  -- Example
  t = 0.6, d = 1, x = 2
  da = 0.6, db = 0.4
    [split t d]
  xa*p = 3/5, xb*q = 7/5,
    [split (t/d) x]
  da*xa = 3/5, db*xb = 7/5
    [split t (d*x)]

  xb = (7/5)/0.4 = 3.5
    [db*xb/db = xb]
  xa = (3/5)/0.6 = 1
    [da*xa/da = xa]

  p = (2 - 7/5) / 1 = 0.6
    [p def]
  q = (2 - 3/5) / 3.5 = 0.4
    [q def]

  >>> split 0.6 (1,(2,_)^.note)^.note -- 2
            ( (0.6,(1,a)^.note)^.note                 -- da*xa
            , (0.4,(3.5,mempty)^.note)^.note            -- db*xb

-}
instance (HasDuration a, Splittable a, Transformable a) => Splittable (Note a) where
  split t ((^. from note) -> (d, x)) = over both (^. note) $ split' t d x

split' :: (Transformable a, HasDuration a, Splittable a) => Duration -> Duration -> a -> ((Duration, a), (Duration, a))
split' t d x = ((da, compress p xa_p), (db, compress q xb_q))
  where
    -- We are really returning ((da, xa), (db, xb))
    -- However because of the polymorphic value, we must derive xa and xb from split (t/d) x, p and q

    -- (da+db)       = split t d
    -- (xa*p+xb*q)   = split (t/d) x
    -- (da*xa+db*xb) = split t (d*x)
    (da, db) = split t d
    (xa_p, xb_q) = split (t / d) x
    (da_xa, db_xb) = split t (d * (x ^. duration))
    xa = da_xa / da
    xb = db_xb / db
    p = ((x ^. duration) - (xb_q ^. duration)) / xa
    q = ((x ^. duration) - (xa_p ^. duration)) / xb

instance IsString a => IsString (Note a) where
  fromString = pure . fromString

instance IsPitch a => IsPitch (Note a) where
  fromPitch = pure . fromPitch

instance IsInterval a => IsInterval (Note a) where
  fromInterval = pure . fromInterval

instance IsDynamics a => IsDynamics (Note a) where
  fromDynamics = pure . fromDynamics

instance ToJSON a => ToJSON (Note a) where
  -- TODO meta
  toJSON a = JSON.object [("duration", toJSON d), ("value", toJSON x)]
    where
      (d, x) = a ^. from note

instance FromJSON a => FromJSON (Note a) where
  parseJSON (JSON.Object x) = liftA2 (\x y -> (x, y) ^. note) dur value
    where
      dur = x JSON..: "duration"
      value = x JSON..: "value"
  parseJSON _ = empty

-- | View a note value as a pair of the original value and a stretch factor.
note :: Iso (Duration, a) (Duration, b) (Note a) (Note b)
note = _Unwrapped

-- | Access the note value.
-- Taking a value out carries out the stretch (using the 'Transformable' instance),
-- while putting a value in carries out the reverse transformation.
--
-- >>> view notee $ (2,3::Duration)^.note
-- 6
--
-- >>> set notee 6 $ (2,1::Duration)^.note
-- (2,3)^.note
notee :: (Transformable a, Transformable b) => Lens (Note a) (Note b) a b
notee = _Wrapped `dependingOn` (transformed . stretching)

-- | A note value as a duration carrying an associated value.
-- Whitness by picking a trivial value.
--
-- >>> 2^.durationNote
-- (2,())^.note
durationNote :: Iso' Duration (Note ())
durationNote = iso (\d -> (d, ()) ^. note) (^. duration)
-- >>> (pure ())^.from durationNote
-- 1
-- >>> (pure () :: Note ())^.duration
-- 1
