{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE StandaloneDeriving #-}

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
module Data.Music.MusicXml.Pitch
  ( Pitch,
    DisplayPitch,
    PitchClass (..),
    Semitones (..),
    noSemitones,
    Octaves (..),
    Fifths (..),
    Line (..),
    Mode (..),
    Accidental (..),
  )
where

import Data.AffineSpace ((.-.))
import Music.Pitch (accidental, name, octaves)
import Music.Pitch.Literal

type Pitch = (PitchClass, Maybe Semitones, Octaves)

type DisplayPitch = (PitchClass, Octaves)

data Mode
  = Major
  | Minor
  | Dorian
  | Phrygian
  | Lydian
  | Mixolydian
  | Aeolian
  | Ionian
  | Locrian
  | NoMode
  deriving (Read)

data Accidental = DoubleFlat | Flat | Natural | Sharp | DoubleSharp
  deriving (Show)

data PitchClass = C | D | E | F | G | A | B
  deriving (Read)

newtype Semitones = -- | Semitones, i.e 100 cent
  Semitones {getSemitones :: Double}
  deriving (Show)

newtype Octaves = -- | Octaves, i.e. 1200 cent
  Octaves {getOctaves :: Int}
  deriving (Show)

newtype Fifths = -- | Number of fifths upwards relative to C (i.e. F is -1, G is 1)
  Fifths {getFifths :: Int}
  deriving (Show)

newtype Line = -- | Line number, from bottom (i.e. 1-5)
  Line {getLine :: Int}
  deriving (Show)

noSemitones :: Maybe Semitones
noSemitones = Nothing

deriving instance Eq PitchClass

deriving instance Ord PitchClass

deriving instance Enum PitchClass

deriving instance Show PitchClass

deriving instance Eq Accidental

deriving instance Ord Accidental

deriving instance Enum Accidental

deriving instance Eq Mode

deriving instance Ord Mode

deriving instance Enum Mode

deriving instance Show Mode

deriving instance Eq Semitones

deriving instance Ord Semitones

deriving instance Num Semitones

deriving instance Enum Semitones

deriving instance Fractional Semitones

deriving instance Eq Octaves

deriving instance Ord Octaves

deriving instance Num Octaves

deriving instance Enum Octaves

deriving instance Real Octaves

deriving instance Integral Octaves

deriving instance Eq Fifths

deriving instance Ord Fifths

deriving instance Num Fifths

deriving instance Enum Fifths

deriving instance Eq Line

deriving instance Ord Line

deriving instance Num Line

deriving instance Enum Line

instance IsPitch Pitch where
  fromPitch p =
    let i = p .-. c
     in ( toEnum $ fromEnum $ name p,
          Just $ fromIntegral $ accidental p,
          fromIntegral $ octaves i + 4
        )

instance IsPitch DisplayPitch where
  fromPitch p =
    let i = p .-. c
     in ( toEnum $ fromEnum $ name p,
          fromIntegral $ octaves i + 4
        )
