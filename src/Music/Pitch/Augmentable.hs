{-# LANGUAGE StandaloneDeriving #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing
  -fno-warn-unused-imports
  -fno-warn-redundant-constraints #-}

------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

-- |
-- Copyright   : (c) Hans Hoglund 2012
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
module Music.Pitch.Augmentable
  ( -- * Augmentable class
    Augmentable (..),
    augmentN,
  )
where

import Data.Functor.Couple
import Data.Ratio

-- |
-- Class of things that can be augmented.
--
-- ==== Laws
--
-- [/inverse/]
--
--    @augment . diminish = id = diminish . augment@
class Augmentable a where
  -- |
  -- Increase the size of this interval by one.
  augment :: a -> a

  -- |
  -- Decrease the size of this interval by one.
  diminish :: a -> a

instance Augmentable Double where
  augment = (+ 1)

  diminish = subtract 1

instance Augmentable Integer where
  augment = (+ 1)

  diminish = subtract 1

instance Integral a => Augmentable (Ratio a) where
  augment = (+ 1)

  diminish = subtract 1

instance Augmentable a => Augmentable [a] where
  augment = fmap augment

  diminish = fmap diminish

instance Augmentable a => Augmentable (b, a) where
  augment = fmap augment

  diminish = fmap diminish

deriving instance (Augmentable a) => Augmentable (Couple b a)

{-
augmented :: Augmentable a => Iso' a a
augmented = iso augment diminish
-}

augmentN :: Augmentable a => Int -> a -> a
augmentN n x
  | n < 0 = iterate diminish x !! n
  | n == 0 = x
  | n > 0 = iterate augment x !! n
  | otherwise = error "impossible"
