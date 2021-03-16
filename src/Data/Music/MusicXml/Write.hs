{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-unused-matches #-}

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
module Data.Music.MusicXml.Write
  ( WriteMusicXml (..),
  )
where

import Text.XML.Light hiding (Line)
import qualified Data.Char as Char
import qualified Data.List as List
import Data.Maybe (maybeToList)
import Data.Music.MusicXml.Pitch
import Data.Music.MusicXml.Score
import Data.Music.MusicXml.Time
import Data.Semigroup
import Prelude hiding (getLine)
import GHC.Stack (HasCallStack)

class WriteMusicXml a where
  write :: a -> [Element]

-- This instance is used by toXml and should return a single list
instance WriteMusicXml Score where
  write
    ( Partwise
        attr
        header
        parts
      ) =
      single
        $ unode "score-partwise"
        $ write header <> writePartwise parts
  write
    ( Timewise
        attr
        header
        measures
      ) =
      single
        $ unode "timewise-score"
        $ write header <> writeTimewise measures

writePartwise :: [(PartAttrs, [(MeasureAttrs, Music)])] -> [Element]

writeTimewise :: [(MeasureAttrs, [(PartAttrs, Music)])] -> [Element]

writePartwise =
  fmap
    ( \(attrs, measures) ->
        writePartElem attrs $
          fmap
            ( \(attrs, music) ->
                writeMeasureElem attrs $
                  writeMusic music
            )
            measures
    )

writeTimewise =
  fmap
    ( \(attrs, parts) ->
        writeMeasureElem attrs $
          fmap
            ( \(attrs, music) ->
                writePartElem attrs $
                  writeMusic music
            )
            parts
    )

writePartElem attrs = addPartAttrs attrs . unode "part"

writeMeasureElem attrs = addMeasureAttrs attrs . unode "measure"

writeMusic = concatMap write . getMusic

addScoreAttrs :: ScoreAttrs -> Element -> Element

addPartAttrs :: PartAttrs -> Element -> Element

addMeasureAttrs :: MeasureAttrs -> Element -> Element

addScoreAttrs (ScoreAttrs []) = id
addScoreAttrs (ScoreAttrs xs) = addAttr (uattr "version" $ concatSep "." $ map show xs)

addPartAttrs (PartAttrs x) = addAttr (uattr "id" x)

addMeasureAttrs (MeasureAttrs implicit number) =
  let yesNo = if implicit then "yes" else "no"
  in addAttr (uattr "number" number) . addAttr (uattr "implicit" yesNo)

instance WriteMusicXml ScoreHeader where
  write
    ( ScoreHeader
        title
        mvmNumber
        mvm
        ident
        partList
      ) =
      mempty <> writeTitle title
        <> writeMvmNumber (show <$> mvmNumber)
        <> writeMvm mvm
        <> writeIdent ident
        <> writePartList partList
      where
        writeTitle, writeMvm :: Maybe String -> [Element]
        writeIdent :: Maybe Identification -> [Element]
        writePartList :: PartList -> [Element]
        writeTitle = fmap (unode "title") . maybeToList
        writeMvmNumber = fmap (unode "movement-number") . maybeToList
        writeMvm = fmap (unode "movement-title") . maybeToList
        writeIdent = single . unode "identification" . (write =<<) . maybeToList
        writePartList = single . unode "part-list" . (write =<<) . getPartList

instance WriteMusicXml Identification where
  write (Identification creators) = map writeCreator creators
    where
      writeCreator (Composer n) = unode "creator" (uattr "type" "composer", n)
      writeCreator (Lyricist n) = unode "creator" (uattr "type" "lyricist", n)
      writeCreator (Arranger n) = unode "creator" (uattr "type" "arranger", n)
      writeCreator (OtherCreator t n) = unode "creator" (uattr "type" t, n)

-- ----------------------------------------------------------------------------------
-- Part list
-- ----------------------------------------------------------------------------------

instance WriteMusicXml PartListElem where
  write
    ( Part
        id
        name
        abbrev
        nameDisplay
        abbrevDisplay
      ) =
      single
        $ addAttr (uattr "id" id)
        $ unode "score-part"
        $ mconcat
          [ writeName name,
            writeAbbrev abbrev,
            writeNameDisplay nameDisplay,
            writeAbbrevDisplay abbrevDisplay
          ]
      where
        writeName = single . unode "part-name"
        writeAbbrev = maybeToList . fmap (unode "part-abbreviation")
        writeNameDisplay = maybeToList . fmap (unode "part-name-display" . unode "display-text")
        writeAbbrevDisplay = maybeToList . fmap (unode "part-abbreviation-display" . unode "display-text")
  write
    ( Group
        level
        startStop
        name
        abbrev
        symbol
        barlines
        time
      ) =
      single
        $ addAttr (uattr "number" $ show $ getLevel level)
        $ addAttr (uattr "type" $ writeStartStop startStop)
        $ unode "part-group"
        $ mempty
          <> writeName name
          <> writeAbbrev abbrev
          <> writeSymbol symbol
          <> writeBarlines barlines
      where
        writeName = maybeToList . fmap (unode "group-name")
        writeAbbrev = maybeToList . fmap (unode "group-abbreviation")
        writeSymbol = maybeToList . fmap (unode "group-symbol" . writeGroupSymbol)
        writeBarlines = maybeToList . fmap (unode "group-barline" . writeGroupBarlines)

writeGroupSymbol :: GroupSymbol -> String

writeGroupBarlines :: GroupBarlines -> String

-- ----------------------------------------------------------------------------------
-- Music
-- ----------------------------------------------------------------------------------

instance WriteMusicXml MusicElem where
  write (MusicAttributes x) = single $ unode "attributes" $ concatMap write x
  write (MusicNote x) = single $ unode "note" $ write x
  write (MusicDirection x) = single $ unode "direction" (unode "direction-type" $ write x)
  write (MusicBackup d) = single $ unode "backup" (unode "duration" $ show $ getDivs d)
  write (MusicForward d) = single $ unode "forward" (unode "duration" $ show $ getDivs d)
  write (MusicBarline x) = write x
  write xs = error $ "Unsupported MusicElem: " ++ show xs

-- ----------------------------------------------------------------------------------
-- Attributes
-- ----------------------------------------------------------------------------------

instance WriteMusicXml Attributes where
  write (Divisions divs) =
    single $ unode "divisions"
      $ show
      $ getDivs divs
  write (Clef sign line octaveChange) =
    single
      $ unode
        "clef"
      $ [ unode "sign" (writeClef sign),
          unode "line" (show $ getLine line)
        ]
        ++ case octaveChange of
          Nothing -> []
          Just (OctaveChange n) -> [unode "clef-octave-change" (show n)]
  write (Key fifths mode) =
    single $
      unode
        "key"
        [ unode "fifths" (show $ getFifths fifths),
          unode "mode" (writeMode mode)
        ]
  write (Time CommonTime) =
    single $ addAttr (uattr "symbol" "common") $
      unode
        "time"
        [ unode "beats" (show @Integer 4),
          unode "beat-type" (show @Integer 4)
        ]
  write (Time CutTime) =
    single $ addAttr (uattr "symbol" "cut") $
      unode
        "time"
        [ unode "beats" (show @Integer 2),
          unode "beat-type" (show @Integer 2)
        ]
  write (Time (DivTime beats beatType)) =
    single $
      unode
        "time"
        [ unode "beats" (show $ getBeat beats),
          unode "beat-type" (show $ getBeatType beatType)
        ]
  write (Staves n) = single $ unode "staves" $ show n
  write (Transpose d c octaveChange) =
    single
      $ unode
        "transpose"
      $ [ unode "diatonic" (show d),
          unode "chromatic" (show c)
        ]
        ++ case octaveChange of
          Nothing -> []
          Just (OctaveChange n) -> [unode "octave-change" (show n)]

  write xs = error $ "Unsupported Attributes: " ++ show xs

-- ----------------------------------------------------------------------------------
-- Notes
-- ----------------------------------------------------------------------------------

instance WriteMusicXml NoteProps where
  write
    ( NoteProps
        instrument -- TODO
        voice
        typ
        dots
        accidental -- TODO
        timeMod -- TODO
        stem -- TODO
        noteHead
        noteHeadText -- TODO
        staff -- TODO
        beam
        notations
        lyrics -- TODO
      ) =
      mempty
        -- TODO instrument
        <> maybeOne (\n -> unode "voice" $ show n) voice
        <> maybeOne (\(noteVal, noteSize) -> unode "type" (writeNoteVal noteVal)) typ
        <> replicate (fromIntegral dots) (unode "dot" ())
        -- TODO accidental
        <> maybeOne
          ( \(m, n) ->
              unode
                "time-modification"
                [ unode "actual-notes" (show m),
                  unode "normal-notes" (show n)
                ]
          )
          timeMod
        -- TODO stem
        <> maybeOne (\(nh, _, _) -> unode "notehead" (writeNoteHead nh)) noteHead
        -- TODO notehead-text
        -- TODO staff
        <> maybeOne
          ( \(n, typ) ->
              addAttr (uattr "number" $ show $ getLevel n)
                $ unode "beam"
                $ writeBeamType typ
          )
          beam
        <> case notations of
          [] -> []
          ns -> [unode "notations" (concatMap write ns)]

instance WriteMusicXml FullNote where
  write
    ( Pitched
        isChord
        (steps, alter, octaves)
      ) =
      mempty
        <> singleIf isChord (unode "chord" ())
        <> single
          ( unode
              "pitch"
              ( mempty
                  <> single ((unode "step" . show) steps)
                  <> maybeOne (unode "alter" . show . getSemitones) alter
                  <> single ((unode "octave" . show . getOctaves) octaves)
              )
          )
  write
    ( Unpitched
        isChord
        Nothing
      ) =
      mempty
        <> singleIf isChord (unode "chord" ())
        <> single (unode "unpitched" ())
  write
    ( Unpitched
        isChord
        (Just (steps, octaves))
      ) =
      mempty
        <> singleIf isChord (unode "chord" ())
        <> single
          ( unode
              "unpitched"
              ( mempty
                  <> single ((unode "display-step" . show) steps)
                  <> single ((unode "display-octave" . show . getOctaves) octaves)
              )
          )
  write
    ( Rest
        isChord
        Nothing
      ) =
      mempty
        <> singleIf isChord (unode "chord" ())
        <> single (unode "rest" ())
  write
    ( Rest
        isChord
        (Just (steps, octaves))
      ) =
      mempty
        <> singleIf isChord (unode "chord" ())
        <> single
          ( unode
              "rest"
              ( mempty
                  <> single ((unode "display-step" . show) steps)
                  <> single ((unode "display-octave" . show . getOctaves) octaves)
              )
          )

instance WriteMusicXml Note where
  write
    ( Note
        full
        dur
        ties
        props
      ) =
      write full <> writeDuration dur
        <> concatMap writeTie ties
        <> write props
  write
    ( CueNote
        full
        dur
        props
      ) =
      [unode "cue" ()] <> write full
        <> writeDuration dur
        <> write props
  write
    ( GraceNote
        full
        ties
        props
      ) =
      [unode "grace" ()] <> write full
        <> concatMap writeTie ties
        <> write props

writeDuration :: Duration -> [Element]
writeDuration = single . unode "duration" . show . getDivs

writeTie :: Tie -> [Element]
writeTie typ = single $ addAttr (uattr "type" $ writeStartStopContinue typ) $ unode "tie" ()

-- ----------------------------------------------------------------------------------
-- Notations
-- ----------------------------------------------------------------------------------

instance WriteMusicXml Notation where
  write (Tied typ) =
    single
      $ addAttr (uattr "type" $ writeStartStopContinue typ)
      $ unode "tied" ()
  write (Slur level typ) =
    single
      $ addAttr (uattr "number" $ show $ getLevel level)
      $ addAttr (uattr "type" $ writeStartStopContinue typ)
      $ unode "slur" ()
  write (Tuplet level typ) =
    single
      $ addAttr (uattr "number" $ show $ getLevel level)
      $ addAttr (uattr "type" $ writeStartStopContinue typ)
      $ unode "tuplet" ()
  write (Glissando level typ lineTyp text) = single
    $ addAttr (uattr "number" $ show $ getLevel level)
    $ addAttr (uattr "type" $ writeStartStopContinue typ)
    $ addAttr (uattr "line-type" $ writeLineType lineTyp)
    $ case text of
      Nothing -> unode "glissando" ()
      Just text -> unode "glissando" text
  write (Slide level typ lineTyp text) = single
    $ addAttr (uattr "number" $ show $ getLevel level)
    $ addAttr (uattr "type" $ writeStartStopContinue typ)
    $ addAttr (uattr "line-type" $ writeLineType lineTyp)
    $ case text of
      Nothing -> unode "slide" ()
      Just text -> unode "slide" text
  write (Ornaments xs) = single $ unode "ornaments" (concatMap writeOrnamentWithAcc xs)
    where
      writeOrnamentWithAcc (o, as) =
        write o
          <> fmap (unode "accidental-mark" . writeAccidental) as
  write (Technical xs) = single $ unode "technical" (concatMap write xs)
  write (Articulations xs) = single $ unode "articulations" (concatMap write xs)
  write (DynamicNotation dyn) = single $ unode "dynamics" (writeDynamics dyn)
  write (Fermata sign) = single $ unode "fermata" (writeFermataSign sign)
  write Arpeggiate = single $ unode "arpeggiate" ()
  write NonArpeggiate = single $ unode "non-arpeggiate" ()
  write (AccidentalMark acc) = single $ unode "accidental-mark" (writeAccidental acc)
  write (OtherNotation not) = notImplemented "OtherNotation"

instance WriteMusicXml Ornament where
  write TrillMark = single $ unode "trill-mark" ()
  write Turn = single $ unode "turn" ()
  write DelayedTurn = single $ unode "delayed-turn" ()
  write InvertedTurn = single $ unode "inverted-turn" ()
  write DelayedInvertedTurn = single $ unode "delayed-inverted-turn" ()
  write VerticalTurn = single $ unode "vertical-turn" ()
  write Shake = single $ unode "shake" ()
  write WavyLine = single $ unode "wavyline" ()
  write Mordent = single $ unode "mordent" ()
  write InvertedMordent = single $ unode "inverted-mordent" ()
  write Schleifer = single $ unode "schleifer" ()
  write (Tremolo num) = single $ unode "tremolo" (show num)
  write xs = error $ "Unsupported Ornament: " ++ show xs

instance WriteMusicXml Technical where
  write UpBow = single $ unode "up-bow" ()
  write DownBow = single $ unode "down-bow" ()
  write Harmonic = single $ unode "harmonic" ()
  write OpenString = single $ unode "openstring" ()
  write ThumbPosition = single $ unode "thumb-position" ()
  write (Fingering f) = single $ unode "fingering" (show f)
  write Pluck = single $ unode "pluck" ()
  write DoubleTongue = single $ unode "double-tongue" ()
  write TripleTongue = single $ unode "triple-tongue" ()
  write Stopped = single $ unode "stopped" ()
  write SnapPizzicato = single $ unode "snap-pizzicato" ()
  write (Fret n) = single $ unode "fret" (show n)
  write (String s) = single $ unode "string" (show s)
  write HammerOn = single $ unode "hammer-on" ()
  write PullOff = single $ unode "pull-off" ()
  write Bend = single $ unode "bend" ()
  write Tap = single $ unode "tap" ()
  write Heel = single $ unode "heel" ()
  write Toe = single $ unode "toe" ()
  write Fingernails = single $ unode "fingernails" ()
  write Hole = single $ unode "hole" ()
  write Arrow = single $ unode "arrow" ()
  write Handbell = single $ unode "handbell" ()
  write (OtherTechnical tech) = notImplemented ("OtherTechnical " <> tech)

instance WriteMusicXml Articulation where
  write Accent = single $ unode "accent" ()
  write StrongAccent = single $ unode "strong-accent" ()
  write Staccato = single $ unode "staccato" ()
  write Tenuto = single $ unode "tenuto" ()
  write DetachedLegato = single $ unode "detached-legato" ()
  write Staccatissimo = single $ unode "staccatissimo" ()
  write Spiccato = single $ unode "spiccato" ()
  write Scoop = single $ unode "scoop" ()
  write Plop = single $ unode "plop" ()
  write Doit = single $ unode "doit" ()
  write Falloff = single $ unode "falloff" ()
  write BreathMark = single $ unode "breathmark" ()
  write Caesura = single $ unode "caesura" ()
  write Stress = single $ unode "stress" ()
  write Unstress = single $ unode "unstress" ()
  write OtherArticulation = notImplemented "OtherArticulation"

-- ----------------------------------------------------------------------------------
-- Directions
-- ----------------------------------------------------------------------------------

instance WriteMusicXml Direction where
  write (Rehearsal str) = single $ unode "rehearsal" str
  write Segno = single $ unode "segno" ()
  write (Words str) = single $ unode "words" str
  write Coda = single $ unode "coda" ()
  write (Crescendo Start) = single $ addAttr (uattr "type" "crescendo") $ unode "wedge" ()
  write (Diminuendo Start) = single $ addAttr (uattr "type" "diminuendo") $ unode "wedge" ()
  write (Crescendo Stop) = single $ addAttr (uattr "type" "stop") $ unode "wedge" ()
  write (Diminuendo Stop) = single $ addAttr (uattr "type" "stop") $ unode "wedge" ()
  write (Dynamics dyn) = single $ unode "dynamics" (writeDynamics dyn)
  write (Metronome noteVal dotted tempo) =
    single $ unode "metronome" $
      [unode "beat-unit" (writeNoteVal noteVal)]
        <> singleIf dotted (unode "beat-unit-dot" ())
        <> [unode "per-minute" (show $ round @Double @Integer $ getTempo tempo)]
  write Bracket = notImplemented "Unsupported directions"
  write (OtherDirection dir) = notImplemented ("OtherDirection " <> dir)
  write xs = error $ "Unsupported Direction: " ++ show xs

-- ----------------------------------------------------------------------------------
-- Barline
-- ----------------------------------------------------------------------------------

instance WriteMusicXml Barline where
  write (Barline location style repeat) =
    single
      $ addAttr (uattr "location" (show location))
      $ unode "barline"
      $ [unode "bar-style" (show style)]
        <> maybe [] write repeat

instance WriteMusicXml Repeat where
  write (Repeat dir) = single $ addAttr (uattr "direction" (show dir)) $ unode "repeat" ()

-- ----------------------------------------------------------------------------------
-- Lyrics
-- ----------------------------------------------------------------------------------

instance WriteMusicXml Lyric where
  write = notImplemented "WriteMusicXml instance for Lyric"

-- ----------------------------------------------------------------------------------
-- Basic types
-- ----------------------------------------------------------------------------------

writeBeamType BeginBeam = "begin" :: String
writeBeamType ContinueBeam = "continue"
writeBeamType EndBeam = "end"
writeBeamType ForwardHook = "forward-hook"
writeBeamType BackwardHook = "backward-hook"

writeStartStop = writeStartStopContinueChange

writeStartStopChange = writeStartStopContinueChange

writeStartStopContinue = writeStartStopContinueChange

writeStartStopContinueChange Start = "start" :: String
writeStartStopContinueChange Stop = "stop"
writeStartStopContinueChange Continue = "continue"
writeStartStopContinueChange Change = "change"

writeStemDirection StemDown = "down" :: String
writeStemDirection StemUp = "up"
writeStemDirection StemNone = "none"
writeStemDirection StemDouble = "double"

writeLineType Solid = "solid" :: String
writeLineType Dashed = "dashed"
writeLineType Dotted = "dotted"
writeLineType Wavy = "wavy"

writeNoteHead SlashNoteHead = "slash" :: String
writeNoteHead TriangleNoteHead = "triangle"
writeNoteHead DiamondNoteHead = "diamond"
writeNoteHead SquareNoteHead = "square"
writeNoteHead CrossNoteHead = "cross"
writeNoteHead XNoteHead = "x"
writeNoteHead CircleXNoteHead = "circle"
writeNoteHead InvertedTriangleNoteHead = "inverted-triangle"
writeNoteHead ArrowDownNoteHead = "arrow-down"
writeNoteHead ArrowUpNoteHead = "arrow-up"
writeNoteHead SlashedNoteHead = "slashed"
writeNoteHead BackSlashedNoteHead = "back-slashed"
writeNoteHead NormalNoteHead = "normal"
writeNoteHead ClusterNoteHead = "cluster"
writeNoteHead CircleDotNoteHead = "circle"
writeNoteHead LeftTriangleNoteHead = "left-triangle"
writeNoteHead RectangleNoteHead = "rectangle"
writeNoteHead NoNoteHead = "none"

writeAccidental DoubleFlat = "double-flat" :: String
writeAccidental Flat = "flat"
writeAccidental Natural = "natural"
writeAccidental Sharp = "sharp"
writeAccidental DoubleSharp = "double-sharp"

writeNoteVal :: NoteVal -> String
writeNoteVal (NoteVal x)
  | x == (1 / 1024) = "1024th"
  | x == (1 / 512) = "512th"
  | x == (1 / 256) = "256th"
  | x == (1 / 128) = "128th"
  | x == (1 / 64) = "64th"
  | x == (1 / 32) = "32nd"
  | x == (1 / 16) = "16th"
  | x == (1 / 8) = "eighth"
  | x == (1 / 4) = "quarter"
  | x == (1 / 2) = "half"
  | x == (1 / 1) = "whole"
  | x == (2 / 1) = "breve"
  | x == (4 / 1) = "long"
  | x == (8 / 1) = "maxima"
  | otherwise = error $ "Data.Music.MusicXml.Write.wrietNoteVal: Invalid note value:" ++ show x

writeClef :: ClefSign -> String
writeClef GClef = "G"
writeClef CClef = "C"
writeClef FClef = "F"
writeClef PercClef = "percussion"
writeClef TabClef = "tab"

writeMode :: Mode -> String
writeMode NoMode = "none"
writeMode x = toLowerString . show $ x

writeGroupSymbol GroupBrace = "brace" :: String
writeGroupSymbol GroupLine = "line"
writeGroupSymbol GroupBracket = "bracket"
writeGroupSymbol GroupSquare = "square"
writeGroupSymbol NoGroupSymbol = "none"

writeGroupBarlines GroupBarLines = "yes" :: String
writeGroupBarlines GroupNoBarLines = "no"
writeGroupBarlines GroupMensurstrich = "Mensurstrich"

writeFermataSign NormalFermata = "normal" :: String
writeFermataSign AngledFermata = "angled"
writeFermataSign SquaredFermata = "squared"

writeDynamics x = unode (toLowerString $ show x) ()

-- ----------------------------------------------------------------------------------

-- XML aliases

addAttr :: Attr -> Element -> Element

addAttrs :: [Attr] -> Element -> Element

addAttr = add_attr

addAttrs = add_attrs

uattr :: String -> String -> Attr
uattr n = Attr (unqual n)

-- Misc

sep :: a -> [a] -> [a]
sep = List.intersperse

concatSep :: [a] -> [[a]] -> [a]
concatSep x = concat . sep x

toUpperChar :: Char -> Char
toUpperChar = Char.toUpper

toLowerChar :: Char -> Char
toLowerChar = Char.toLower

toUpperString :: String -> String
toUpperString = fmap Char.toUpper

toLowerString :: String -> String
toLowerString = fmap Char.toLower

toCapitalString :: String -> String
toCapitalString [] = []
toCapitalString (x : xs) = toUpperChar x : toLowerString xs

one :: (a -> b) -> a -> [b]
one f = single . f

maybeOne :: (a -> b) -> Maybe a -> [b]
maybeOne f = maybeToList . fmap f

single :: a -> [a]
single = return

fromSingle :: [a] -> a
fromSingle [x] = x
fromSingle _ = error "fromSingle: non-single list"

singleIf :: Bool -> a -> [a]
singleIf p x
  | not p = []
  | otherwise = [x]

notImplemented :: HasCallStack => String -> a
notImplemented x = error $ "Not implemented: " ++ x
