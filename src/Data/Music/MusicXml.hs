{-# OPTIONS_GHC -fno-warn-dodgy-exports #-}

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
-- A Haskell representation of MusicXML 3.0.
--
-- You may want to use the "Data.Music.MusicXml.Simple" module to generate the representation.
--
-- For an introduction to MusicXML, see <http://www.makemusic.com/musicxml/tutorial>.
module Data.Music.MusicXml
  ( -- * Score
    Score (..),
    ScoreHeader (..),
    Identification (..),
    Creator (..),
    Defaults (..),
    ScoreAttrs (..),
    PartAttrs (..),
    MeasureAttrs (..),

    -- ** Part list
    PartList (..),
    PartListElem (..),

    -- * Music
    Music (..),
    MusicElem (..),

    -- ** Attributes
    Attributes (..),
    TimeSignature (..),
    ClefSign (..),

    -- ** Notes
    Note (..),
    FullNote (..),
    IsChord,
    noChord,
    Tie (..),
    noTies,
    NoteProps (..),
    HasNoteProps (..),

    -- ** Notations
    Notation (..),
    Articulation (..),
    Ornament (..),
    Technical (..),

    -- ** Directions
    Direction (..),

    -- ** Lyrics
    Lyric (..),

    -- * Basic types

    -- ** Pitch
    Pitch (..),
    DisplayPitch (..),
    PitchClass,
    Semitones (..),
    noSemitones,
    Octaves (..),
    Fifths (..),
    Line (..),
    Mode (..),
    Accidental (..),

    -- ** Time
    Duration (..),
    NoteType (..),
    Divs (..),
    NoteVal (..),
    NoteSize (..),
    Beat (..),
    BeatType (..),

    -- ** Dynamics
    Dynamics,
    -----------------------------------------------------------------------------

    -- ** Misc
    StemDirection (..),
    NoteHead (..),
    LineType (..),
    Level (..),
    BeamType (..),
    StartStop (..),
    StartStopChange (..),
    StartStopContinue (..),
    StartStopContinueChange (..),
    -----------------------------------------------------------------------------

    -- * Import and export functions

    -----------------------------------------------------------------------------
    toXml,
    showXml,
    readXml,
  )
where

import Data.Music.MusicXml.Dynamics
import Data.Music.MusicXml.Pitch
import Data.Music.MusicXml.Read
import Data.Music.MusicXml.Score
import Data.Music.MusicXml.Write
import Text.XML.Light hiding (Line)

-- --------------------------------------------------------------------------------
-- Import and export functions
-- --------------------------------------------------------------------------------

-- |
-- Render a score as a MusicXML string.
showXml :: Score -> String
showXml = ppTopElement . toXml

-- |
-- Render a score as MusicXML.
toXml :: Score -> Element
toXml = fromSingle . write

-- |
-- Parse a MusicXML string into a score.
readXml :: String -> Maybe Score
readXml source = parseXMLDoc source >>= parseScore

-- --------------------------------------------------------------------------------

fromSingle :: [a] -> a
fromSingle [x] = x
fromSingle _ = error "fromSingle: non-single list"
