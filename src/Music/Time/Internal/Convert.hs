{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing
  -fno-warn-unused-imports #-}
{-# OPTIONS_HADDOCK hide #-}

-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

-- |
-- Copyright   : (c) Hans Hoglund 2012-2014
--
-- License     : BSD-style
--
-- Maintainer  : hans@hanshoglund.se
-- Stability   : experimental
-- Portability : non-portable (TF,GNTD)
--
-- Provides miscellaneous conversions.
module Music.Time.Internal.Convert
  ( reactiveToVoice',
  )
where

import Control.Applicative
import Control.Lens hiding (transform)
import Control.Monad
import Control.Monad.Plus
import Data.AffineSpace
import Data.AffineSpace.Point
import Data.Foldable (Foldable (..))
import qualified Data.Foldable as Foldable
import qualified Data.List as List
import Data.Ord
import Data.Ratio
import Data.Semigroup
import Data.String
import Data.Traversable
import Data.VectorSpace
import Music.Time.Internal.Placed
import Music.Time.Internal.Track
import Music.Time.Note
import Music.Time.Reactive
import Music.Time.Types
import Music.Time.Voice

reactiveToVoice' :: Span -> Reactive a -> Voice a
reactiveToVoice' (view onsetAndOffset -> (u, v)) r = (^. voice) $ fmap (^. note) $ durs `zip` fmap (r `atTime`) times
  where
    times = 0 : filter (\t -> u < t && t < v) (occs r)
    durs = toRelativeTimeN' v times
