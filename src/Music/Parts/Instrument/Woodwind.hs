{-# OPTIONS_GHC
  -fno-warn-name-shadowing
  -fno-warn-unused-imports
  -fno-warn-redundant-constraints #-}

module Music.Parts.Instrument.Woodwind
  ( WoodwindInstrument,
    woodwindInstrument,
    isWoodwindInstrument,
  )
where

import Control.Lens
import Data.List (isPrefixOf)
import Data.Set (Set)
import Music.Parts.Instrument
import Music.Pitch (Ambitus, Clef)
import Music.Pitch.Common (Interval, Pitch)

newtype WoodwindInstrument = WoodwindInstrument {getWoodwindInstrument :: Instrument}

woodwindInstrument :: Prism' Instrument WoodwindInstrument
woodwindInstrument = prism' getWoodwindInstrument (fmap WoodwindInstrument . partial isWoodwindInstrument)

-- TODO move/consolidate
partial :: (a -> Bool) -> a -> Maybe a
partial p x = if p x then Just x else Nothing

isWoodwindInstrument :: Instrument -> Bool
isWoodwindInstrument x = case toMusicXmlSoundId x of
  Nothing -> False
  Just i -> Data.List.isPrefixOf "wind" i

