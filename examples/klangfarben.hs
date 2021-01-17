{-# LANGUAGE TypeFamilies #-}

-- This example shows a Webern style orchestration of a single voice
-- distributed throughout several parts.
--
-- We accomplish this with the zip-like function 'klangfarben'.
module Main where

import Music.Prelude
import qualified Music.Score

main :: IO ()
main = defaultMain music

music :: Music
music =
  compress 4 $ renderAlignedVoice $ aligned 0 0 $
    klangfarben
      ( cycle
          [ violins,
            flutes,
            oboes,
            trumpets,
            tubas,
            clarinets,
            trombones,
            doubleBasses
          ]
      )
      ( mconcat
          [ c,
            e |* 3,
            fs,
            g,
            a |/ 2,
            gs' |* 3,
            g',
            fs',
            as,
            b,
            cs
          ]
      )

klangfarben :: HasParts' a => [GetPart a] -> Voice a -> Voice a
klangfarben ps v = (^. voice) $ zipWith (set parts') ps (v ^. notes)
