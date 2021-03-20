{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}

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
-- Provides smart constructors for the MusicXML representation.
module Data.Music.MusicXml.Simple
  ( module Data.Music.MusicXml,
    -----------------------------------------------------------------------------

    -- * Score and parts

    -----------------------------------------------------------------------------

    -- ** Basic constructors
    fromPart,
    fromParts,

    -- ** Part lists
    partList,
    partListDisplay,
    partListAbbr,
    bracket,
    brace,

    -- ** Measures
    measure,
    bar,
    -- -- ** Others
    -- standardPartAttributes,
    -- header,
    -- setHeader,
    -- setTitle,
    -- setMovementTitle,

    -----------------------------------------------------------------------------

    -- * Top-level attributes

    -----------------------------------------------------------------------------

    -- ** Pitch
    trebleClef,
    altoClef,
    bassClef,
    defaultClef,
    clef,
    defaultKey,
    key,

    -- ** Time
    defaultDivisionsVal,
    defaultDivisions,
    divisions,
    commonTime,
    cutTime,
    time,
    staves,

    -- ** Tempo

    -- TODO #15 tempo
    metronome,
    metronome',
    -----------------------------------------------------------------------------

    -- * Backup and forward

    -----------------------------------------------------------------------------
    backup,
    forward,
    -----------------------------------------------------------------------------

    -- * Notes

    -----------------------------------------------------------------------------

    -- ** Basic constructors
    rest,
    note,
    chord,

    -- ** Voice
    setVoice,

    -- ** Duration
    dot,
    tuplet,
    setNoteVal,
    -- setTimeMod,
    -- beginTuplet,
    -- endTuplet,
    separateDots,

    -- ** Beams
    beam,
    beginBeam,
    continueBeam,
    endBeam,

    -- ** Ties
    beginTie,
    endTie,

    -- ** Note heads
    setNoteHead,

    -- ** Notations
    addNotation,
    -----------------------------------------------------------------------------

    -- * Pitch transformations

    -----------------------------------------------------------------------------

    -- ** Glissando
    beginGliss,
    endGliss,

    -- ** Slides
    beginSlide,
    endSlide,
    -----------------------------------------------------------------------------

    -- * Time transformations

    -----------------------------------------------------------------------------

    -- ** Accelerando and ritardando

    -- TODO #16 accelerando,
    -- TODO #16 ritardando,

    -- ** Fermatas and breaks
    fermata,
    breathMark,
    caesura,
    -----------------------------------------------------------------------------

    -- * Articulation

    -----------------------------------------------------------------------------
    addTechnical,
    addArticulation,

    -- ** Technical
    upbow,
    downbow,
    harmonic,
    openString,

    -- ** Slurs
    slur,
    beginSlur,
    endSlur,

    -- ** Staccato and tenuto
    staccato,
    tenuto,
    spiccato,
    staccatissimo,

    -- ** Accents
    accent,
    strongAccent,

    -- ** Miscellaneous
    scoop,
    plop,
    doit,
    falloff,
    stress,
    unstress,

    -- ** Ornaments
    trill,
    turn,
    shake,
    mordent,
    tremolo,
    -----------------------------------------------------------------------------

    -- * Dynamics

    -----------------------------------------------------------------------------

    -- ** Crescendo and diminuendo
    cresc,
    dim,
    beginCresc,
    endCresc,
    beginDim,
    endDim,

    -- ** Dynamic levels
    dynamic,

    -- ** Both
    crescFrom,
    crescTo,
    crescFromTo,
    dimFrom,
    dimTo,
    dimFromTo,
    -----------------------------------------------------------------------------

    -- * Text

    -----------------------------------------------------------------------------
    text,
    rehearsal,
    segno,
    coda,
    -----------------------------------------------------------------------------

    -- * Barlines/Repeats

    -----------------------------------------------------------------------------
    barline,
    doubleBarline,
    beginRepeat,
    endRepeat,
    -----------------------------------------------------------------------------

    -- * Folds and maps

    -----------------------------------------------------------------------------

    -- mapNote,
    mapMusic,
    foldMusic,
  )
where

import Control.Arrow
import Data.Default
import qualified Data.List as List
import Data.Music.MusicXml
import Data.Music.MusicXml.Score
import Data.Music.MusicXml.Time
import Data.Ratio

-- ----------------------------------------------------------------------------------
-- Score and parts
-- ----------------------------------------------------------------------------------

-- |
-- Create a single-part score.
--
-- > fromPart title composer partName measures
--
-- Example:
--
-- @ 'fromPart' \"Suite\" \"Bach\" \"Cello solo\" [] @
fromPart :: String -> String -> String -> [Music] -> Score
fromPart title composer partName music =
  fromParts title composer (partList [partName]) [music]

-- |
-- Create a multi-part score.
--
-- > fromParts title composer partList parts
--
-- Example:
--
-- @ 'fromParts' \"4'33\" \"Cage\" ('partList' [\"Violin\", \"Viola\", \"Cello\"]) [[]] @
fromParts :: String -> String -> PartList -> [[Music]] -> Score
fromParts title composer partList music =
  Partwise
    def
    (header title composer partList)
    (addPartwiseAttributes music)

-- |
-- Create a part list from instrument names.
partList :: [String] -> PartList
partList = PartList . zipWith (\partId name -> Part partId name Nothing Nothing Nothing) standardPartAttributes

-- |
-- Create a part list from instrument names and displayed names (some applications need the name to be something
-- specific, so use displayed name to override).
partListDisplay :: [(String, String)] -> PartList
partListDisplay = PartList . zipWith (\partId (name, dispName) -> Part partId name Nothing (Just dispName) Nothing) standardPartAttributes

-- |
-- Create a part list from instrument names and abbreviations.
partListAbbr :: [(String, String)] -> PartList
partListAbbr = PartList . zipWith (\partId (name, abbr) -> Part partId name (Just abbr) Nothing Nothing) standardPartAttributes

-- |
-- Enclose the given parts in a bracket.
bracket :: PartList -> PartList
bracket ps =
  PartList $
    mempty
      <> [Group 1 Start Nothing Nothing (Just GroupBracket) (Just GroupBarLines) False]
      <> getPartList ps
      <> [Group 1 Stop Nothing Nothing Nothing Nothing False]

-- |
-- Enclose the given parts in a brace.
brace :: PartList -> PartList
brace ps =
  PartList $
    mempty
      <> [Group 1 Start Nothing Nothing (Just GroupBrace) (Just GroupBarLines) False]
      <> getPartList ps
      <> [Group 1 Stop Nothing Nothing Nothing Nothing False]

-- |
-- Convenient synonym for 'mconcat', allowing us to write things like
--
-- > measure [
-- >    beam [
-- >        note c  (1/8),
-- >        note d  (1/8),
-- >        note e  (1/8),
-- >        note f  (1/8)
-- >    ],
-- >    tuplet 3 2 [
-- >        note g  (1/4),
-- >        note a  (1/4),
-- >        note b  (1/4)
-- >    ]
-- > ]
measure :: [Music] -> Music
measure = mconcat

-- |
-- Convenient synonym for 'mconcat'.
bar :: [Music] -> Music
bar = measure

header :: String -> String -> PartList -> ScoreHeader
header title composer partList = ScoreHeader Nothing Nothing (Just title) (Just (Identification [Composer composer])) partList

setHeader :: ScoreHeader -> Score -> Score
setHeader header (Partwise attrs _ music) = Partwise attrs header music
setHeader header (Timewise attrs _ music) = Timewise attrs header music

setTitle :: String -> ScoreHeader -> ScoreHeader
setTitle title sh = sh {scoreTitle = Just title}

setMovementNumber :: Int -> ScoreHeader -> ScoreHeader
setMovementNumber n sh = sh {mvmNumber = Just n}

setMovementTitle :: String -> ScoreHeader -> ScoreHeader
setMovementTitle t sh = sh {mvmTitle = Just t}

-- | The values P1, P2... which are conventionally used to identify parts in MusicXML.
standardPartAttributes :: [String]
standardPartAttributes = ["P" ++ show @Integer n | n <- [1 ..]]

-- | Given a partwise score (list of parts, which are lists of measures), add part and measure attributes (numbers).
addPartwiseAttributes :: [[Music]] -> [(PartAttrs, [(MeasureAttrs, Music)])]
addPartwiseAttributes = deepZip partIds barIds
  where
    partIds = fmap PartAttrs standardPartAttributes
    barIds = fmap (MeasureAttrs False . show @Integer) [1 ..]
    deepZip :: [a] -> [b] -> [[c]] -> [(a, [(b, c)])]
    deepZip xs ys = zipWith (curry $ second (zip ys)) xs

-- ----------------------------------------------------------------------------------
-- Top-level attributes
-- ----------------------------------------------------------------------------------

trebleClef, altoClef, bassClef :: Music
trebleClef = clef GClef 2
altoClef = clef CClef 3
bassClef = clef FClef 4

defaultClef :: Music
defaultClef = trebleClef

-- |
-- Create a clef.
clef :: ClefSign -> Line -> Music
clef symbol line =
  Music . single $ MusicAttributes $ single $ Clef symbol line Nothing

defaultKey :: Music
defaultKey = key 0 Major

-- |
-- Create a key signature.
key :: Fifths -> Mode -> Music
key n m = Music . single $ MusicAttributes $ single $ Key n m

-- Number of ticks per whole note (we use 768 per quarter like Sibelius).
defaultDivisionsVal :: Divs
defaultDivisionsVal = 768 * 4

-- |
-- Set the tick division to the default value.
defaultDivisions :: Music
defaultDivisions = Music $ single $ MusicAttributes $ single $ Divisions $ defaultDivisionsVal `div` 4

-- |
-- Define the number of ticks per quarter note.
divisions :: Divs -> Music
divisions n = Music . single $ MusicAttributes $ single $ Divisions n

commonTime, cutTime :: Music
commonTime = Music . single $ MusicAttributes $ single $ Time CommonTime
cutTime = Music . single $ MusicAttributes $ single $ Time CutTime

-- |
-- Create a time signature.
time :: Beat -> BeatType -> Music
time a b = Music . single $ MusicAttributes $ single $ Time $ DivTime a b

staves :: Int -> Music
staves n = Music $ single $ MusicAttributes $ single $ Staves (fromIntegral n)

-- |
-- Create a metronome mark.
metronome :: NoteVal -> Tempo -> Music
metronome nv tempo = case dots of
  0 -> metronome' nv' False tempo
  1 -> metronome' nv' True tempo
  _ -> error "Metronome mark requires a maximum of one dot."
  where
    (nv', dots) = separateDots nv

-- |
-- Create a metronome mark.
metronome' :: NoteVal -> Bool -> Tempo -> Music
metronome' nv dot tempo = Music . single $ MusicDirection (Metronome nv dot tempo)

-- TODO #15 tempo

backup :: Duration -> Music
backup d = Music . single $ MusicBackup d

forward :: Duration -> Music
forward d = Music . single $ MusicForward d

-- ----------------------------------------------------------------------------------
-- Barlines
-- ----------------------------------------------------------------------------------

-- | All-purpose barline function.
barline :: Barline -> Music
barline = Music . single . MusicBarline

-- | Inserts double bar at beginning of bar.
doubleBarline :: Music
doubleBarline = barline $ Barline BLLeft BSLightLight Nothing

beginRepeat :: Music
beginRepeat = barline $ Barline BLLeft BSHeavyLight $ Just $ Repeat RepeatForward

endRepeat :: Music
endRepeat = barline $ Barline BLRight BSLightHeavy $ Just $ Repeat RepeatBackward

-- ----------------------------------------------------------------------------------
-- Notes
-- ----------------------------------------------------------------------------------

-- |
-- Create a rest.
--
-- > rest (1/4)
-- > rest (3/8)
-- > rest quarter
-- > rest (dotted eight)
rest :: NoteVal -> Music
-- rest = rest'
rest dur = case dots of
  0 -> rest' dur'
  1 -> rest' dur' <> rest' (dur' / 2)
  2 -> rest' dur' <> rest' (dur' / 2) <> rest' (dur' / 4)
  3 -> rest' dur' <> rest' (dur' / 2) <> rest' (dur' / 4) <> rest' (dur' / 8)
  _ -> error "Data.Music.MusicXml.Simple.rest: too many dots"
  where
    (dur', dots) = separateDots dur

rest' :: NoteVal -> Music
rest' dur = Music . single $ MusicNote (Note def (defaultDivisionsVal `div` denom) noTies (setNoteValP val def))
  where
    -- num = fromIntegral $ numerator $ toRational $ dur
    denom = fromIntegral $ denominator $ toRational dur
    val = NoteVal $ toRational dur

-- |
-- Create a single note.
--
-- > note c   (1/4)
-- > note fs_ (3/8)
-- > note c   quarter
-- > note (c + pure fifth) (dotted eight)
note :: Pitch -> NoteVal -> Music
note pitch dur = note' False pitch dur' dots
  where
    (dur', dots) = separateDots dur

chordNote :: Pitch -> NoteVal -> Music
chordNote pitch dur = note' True pitch dur' dots
  where
    (dur', dots) = separateDots dur

-- |
-- Create a chord.
--
-- > chord [c,eb,fs_] (3/8)
-- > chord [c,d,e] quarter
-- > chord [c,d,e] (dotted eight)
chord :: [Pitch] -> NoteVal -> Music
chord [] d = rest d
chord (p : ps) d = note p d <> Music (concatMap (\p -> getMusic $ chordNote p d) ps)

note' :: Bool -> Pitch -> NoteVal -> Int -> Music
note' isChord pitch dur dots =
  Music . single $
    MusicNote $
      Note
        (Pitched isChord pitch)
        (defaultDivisionsVal `div` denom)
        noTies
        (setNoteValP val $ addDots def)
  where
    addDots = foldl (.) id (replicate dots dotP)
    -- I.e. given a 1/4 note
    -- num ~ 1
    -- denom ~ 4

    -- num = numerator $ toRational $ dur
    denom = fromIntegral $ denominator $ toRational dur
    val = NoteVal $ toRational dur

separateDots :: NoteVal -> (NoteVal, Int)
separateDots = separateDots' [2 / 3, 6 / 7, 14 / 15, 30 / 31, 62 / 63]

separateDots' :: [NoteVal] -> NoteVal -> (NoteVal, Int)
separateDots' [] _nv = errorNoteValue
separateDots' (div : divs) nv
  | isDivisibleBy @Integer 2 nv = (nv, 0)
  | otherwise = (nv', dots' + 1)
  where
    (nv', dots') = separateDots' divs (nv * div)

errorNoteValue = error "Data.Music.MusicXml.Simple.separateDots: Note value must be a multiple of two or dotted"

setVoice :: Int -> Music -> Music
setVoice n = Music . fmap (modifyNoteProps (setVoiceP n)) . getMusic

dot :: Music -> Music
setNoteVal :: NoteVal -> Music -> Music
setTimeMod :: Int -> Int -> Music -> Music
dot = Music . fmap (modifyNoteProps dotP) . getMusic

setNoteVal x = Music . fmap (modifyNoteProps (setNoteValP x)) . getMusic

setTimeMod m n = Music . fmap (modifyNoteProps (setTimeModP m n)) . getMusic

addNotation :: Notation -> Music -> Music
addNotation x = Music . fmap (modifyNoteProps (addNotationP x)) . getMusic

setNoteHead :: NoteHead -> Music -> Music
setNoteHead x = Music . fmap (modifyNoteProps (mapNoteHeadP (const $ Just (x, False, False)))) . getMusic

-- TODO clean up, skip empty notation groups etc
mergeNotations :: [Notation] -> [Notation]
mergeNotations notations =
  mempty
    <> [foldOrnaments ornaments]
    <> [foldTechnical technical]
    <> [foldArticulations articulations]
    <> others
  where
    (ornaments, notations') = List.partition isOrnaments notations
    (technical, _notations'') = List.partition isTechnical notations'
    (articulations, others) = List.partition isArticulations notations'
    isOrnaments (Ornaments _) = True
    isOrnaments _ = False
    isTechnical (Technical _) = True
    isTechnical _ = False
    isArticulations (Articulations _) = True
    isArticulations _ = False
    foldOrnaments = foldr mergeN (Ornaments [])
    foldTechnical = foldr mergeN (Technical [])
    foldArticulations = foldr mergeN (Articulations [])
    (Ornaments xs) `mergeN` (Ornaments ys) = Ornaments (xs <> ys)
    (Technical xs) `mergeN` (Technical ys) = Technical (xs <> ys)
    (Articulations xs) `mergeN` (Articulations ys) = Articulations (xs <> ys)
    _ `mergeN` _ = error "mergeNotations: mergeN: Unexpected"

beginTuplet :: Music -> Music
endTuplet :: Music -> Music
beginTuplet = addNotation (Tuplet 1 Start)

endTuplet = addNotation (Tuplet 1 Stop)

beginBeam :: Music -> Music
continueBeam :: Music -> Music
endBeam :: Music -> Music
beginBeam = Music . fmap (modifyNoteProps (beginBeamP 1)) . getMusic

continueBeam = Music . fmap (modifyNoteProps (continueBeamP 1)) . getMusic

endBeam = Music . fmap (modifyNoteProps (endBeamP 1)) . getMusic

beginTie :: Music -> Music
endTie :: Music -> Music
beginTie = beginTie' . addNotation (Tied Start)

endTie = endTie' . addNotation (Tied Stop)

beginTie' = Music . fmap beginTie'' . getMusic

endTie' = Music . fmap endTie'' . getMusic

beginTie'' (MusicNote (Note full dur ties props)) = MusicNote (Note full dur (ties ++ [Start]) props)
beginTie'' x = x

endTie'' (MusicNote (Note full dur ties props)) = MusicNote (Note full dur (Stop : ties) props)
endTie'' x = x

setNoteValP v x = x {noteType = Just (v, Nothing)}

setVoiceP n x = x {noteVoice = Just (fromIntegral n)}

setTimeModP m n x = x {noteTimeMod = Just (fromIntegral m, fromIntegral n)}

beginBeamP n x = x {noteBeam = Just (n, BeginBeam)}

continueBeamP n x = x {noteBeam = Just (n, ContinueBeam)}

endBeamP n x = x {noteBeam = Just (n, EndBeam)}

dotP x@NoteProps {noteDots = n} = x {noteDots = succ n}

addNotationP n x@NoteProps {noteNotations = ns@_} = x {noteNotations = mergeNotations $ ns ++ [n]}

mapNotationsP f x@NoteProps {noteNotations = ns@_} = x {noteNotations = f ns}

mapStemP f x@NoteProps {noteStem = a@_} = x {noteNotations = f a}

mapNoteHeadP f x@NoteProps {noteNoteHead = a@_} = x {noteNoteHead = f a}

-- ----------------------------------------------------------------------------------

beginGliss :: Music -> Music
endGliss :: Music -> Music
beginSlide :: Music -> Music
endSlide :: Music -> Music
beginGliss = addNotation (Glissando 1 Start Solid Nothing)

endGliss = addNotation (Glissando 1 Stop Solid Nothing)

beginSlide = addNotation (Slide 1 Start Solid Nothing)

endSlide = addNotation (Slide 1 Stop Solid Nothing)

arpeggiate :: Music -> Music
nonArpeggiate :: Music -> Music
arpeggiate = addNotation Arpeggiate

nonArpeggiate = addNotation NonArpeggiate

-- ----------------------------------------------------------------------------------

fermata :: FermataSign -> Music -> Music
breathMark :: Music -> Music
caesura :: Music -> Music
fermata = addNotation . Fermata

breathMark = addNotation (Articulations [BreathMark])

caesura = addNotation (Articulations [Caesura])

-- ----------------------------------------------------------------------------------

addTechnical :: Technical -> Music -> Music
addTechnical x = addNotation (Technical [x])

addArticulation :: Articulation -> Music -> Music
addArticulation x = addNotation (Articulations [x])

upbow = addTechnical UpBow

downbow = addTechnical DownBow

harmonic = addTechnical Harmonic

openString = addTechnical OpenString

beginSlur :: Music -> Music
endSlur :: Music -> Music
beginSlur = addNotation (Slur 1 Start)

endSlur = addNotation (Slur 1 Stop)

accent :: Music -> Music
strongAccent :: Music -> Music
staccato :: Music -> Music
tenuto :: Music -> Music
detachedLegato :: Music -> Music
staccatissimo :: Music -> Music
spiccato :: Music -> Music
scoop :: Music -> Music
plop :: Music -> Music
doit :: Music -> Music
falloff :: Music -> Music
stress :: Music -> Music
unstress :: Music -> Music
accent = addNotation (Articulations [Accent])

strongAccent = addNotation (Articulations [StrongAccent])

staccato = addNotation (Articulations [Staccato])

tenuto = addNotation (Articulations [Tenuto])

detachedLegato = addNotation (Articulations [DetachedLegato])

staccatissimo = addNotation (Articulations [Staccatissimo])

spiccato = addNotation (Articulations [Spiccato])

scoop = addNotation (Articulations [Scoop])

plop = addNotation (Articulations [Plop])

doit = addNotation (Articulations [Doit])

falloff = addNotation (Articulations [Falloff])

stress = addNotation (Articulations [Stress])

unstress = addNotation (Articulations [Unstress])

-- ----------------------------------------------------------------------------------

cresc, dim :: Music -> Music
crescFrom, crescTo, dimFrom, dimTo :: Dynamics -> Music -> Music
crescFromTo, dimFromTo :: Dynamics -> Dynamics -> Music -> Music
cresc = \m -> beginCresc <> m <> endCresc
dim = \m -> beginDim <> m <> endDim

crescFrom x = \m -> dynamic x <> cresc m

crescTo x = \m -> cresc m <> dynamic x

crescFromTo x y = \m -> dynamic x <> cresc m <> dynamic y

dimFrom x = \m -> dynamic x <> dim m

dimTo x = \m -> dim m <> dynamic x

dimFromTo x y = \m -> dynamic x <> dim m <> dynamic y

beginCresc, endCresc, beginDim, endDim :: Music
beginCresc = Music [MusicDirection $ Crescendo Start]
endCresc = Music [MusicDirection $ Crescendo Stop]
beginDim = Music [MusicDirection $ Diminuendo Start]
endDim = Music [MusicDirection $ Diminuendo Stop]

dynamic :: Dynamics -> Music
dynamic level = Music $ [MusicDirection $ Dynamics level]

tuplet :: Int -> Int -> Music -> Music
tuplet m n (Music []) = scaleDur (fromIntegral n / fromIntegral m :: Rational) $ Music []
tuplet m n (Music [xs]) = scaleDur (fromIntegral n / fromIntegral m :: Rational) $ Music [xs]
tuplet m n (Music xs) = scaleDur (fromIntegral n / fromIntegral m :: Rational) $ setTimeMod m n $ (as <> bs <> cs)
  where
    as = beginTuplet $ Music [head xs]
    bs = Music $ init (tail xs)
    cs = endTuplet $ Music [last (tail xs)]

scaleDur x =
  mapMusic
    id
    ( mapNote
        (\f d t p -> (f, round $ fromIntegral d * x, t, p))
        (\f d p -> (f, round $ fromIntegral d * x, p))
        (\f t p -> (f, t, p))
    )
    id

beam :: Music -> Music
beam (Music []) = Music []
beam (Music [xs]) = Music [xs]
beam (Music xs) = as <> bs <> cs
  where
    as = beginBeam $ Music [head xs]
    bs = continueBeam $ Music (init (tail xs))
    cs = endBeam $ Music [last (tail xs)]

slur :: Music -> Music
slur (Music []) = Music []
slur (Music [xs]) = Music [xs]
slur (Music xs) = as <> bs <> cs
  where
    as = beginSlur $ Music [head xs]
    bs = Music $ init (tail xs)
    cs = endSlur $ Music [last (tail xs)]

-- TODO combine tuplet, beam, slur etc

-----------------------------------------------------------------------------

-- * Ornaments

-----------------------------------------------------------------------------

tremolo :: Int -> Music -> Music
tremolo n = addNotation (Ornaments [(Tremolo $ fromIntegral n, [])])

trill :: Music -> Music
turn :: Bool -> Bool -> Music -> Music
shake :: Music -> Music
mordent :: Bool -> Music -> Music
trill = addOrnament TrillMark

turn delay invert = case (delay, invert) of
  (False, False) -> addOrnament Turn
  (True, False) -> addOrnament DelayedTurn
  (False, True) -> addOrnament InvertedTurn
  (True, True) -> addOrnament DelayedInvertedTurn

shake = addOrnament Shake

mordent invert = case invert of
  False -> addOrnament Mordent
  True -> addOrnament InvertedMordent

addOrnament a = addNotation (Ornaments [(a, [])])

-- ----------------------------------------------------------------------------------
-- Text
-- ----------------------------------------------------------------------------------

text :: String -> Music
rehearsal :: String -> Music
text = Music . single . MusicDirection . Words

rehearsal = Music . single . MusicDirection . Rehearsal

segno, coda :: Music
segno = Music . single . MusicDirection $ Segno
coda = Music . single . MusicDirection $ Coda

-- ----------------------------------------------------------------------------------

mapNote fn fc fg = go
  where
    go (Note f d t p) = let (f', d', t', p') = fn f d t p in Note f' d' t' p'
    go (CueNote f d p) = let (f', d', p') = fc f d p in CueNote f' d' p'
    go (GraceNote f t p) = let (f', t', p') = fg f t p in GraceNote f' t' p'

mapMusic :: (Attributes -> Attributes) -> (Note -> Note) -> (Direction -> Direction) -> Music -> Music
mapMusic fa fn fd = foldMusic (MusicAttributes . fmap fa) (MusicNote . fn) (MusicDirection . fd) (Music . return)

foldMusic :: Monoid m => ([Attributes] -> r) -> (Note -> r) -> (Direction -> r) -> (r -> m) -> Music -> m
foldMusic fa fn fd f = mconcat . fmap f . foldMusic' (fmap $ foldMusicElem fa fn fd)

foldMusic' :: ([MusicElem] -> r) -> Music -> r
foldMusic' f (Music x) = f x

foldMusicElem :: ([Attributes] -> r) -> (Note -> r) -> (Direction -> r) -> MusicElem -> r
foldMusicElem = go
  where
    go fa _ _ (MusicAttributes x) = fa x
    go _ fn _ (MusicNote x) = fn x
    go _ _ fd (MusicDirection x) = fd x
    go _ _ _ _ = error "foldMusicElem: Unexpected"

-- ----------------------------------------------------------------------------------

-------------------------------------------------------------------------------------

logBaseR :: forall a. (RealFloat a) => Rational -> Rational -> a
logBaseR k n
  | isInfinite (fromRational n :: a) = logBaseR k (n / k) + 1
logBaseR k n
  | isDenormalized (fromRational n :: a) = logBaseR k (n * k) - 1
logBaseR k n = logBase (fromRational k) (fromRational n)

isDivisibleBy :: (Real a, Real b) => a -> b -> Bool
isDivisibleBy n = equalTo 0.0 . snd . properFraction @Double @Integer . logBaseR (toRational n) . toRational

single x = [x]

equalTo = (==)
