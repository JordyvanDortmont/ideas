﻿module Main where

-- spul integreren met ideas
-- document buggy rules for AM
-- include problemstatement translations
-- second ``for'' ref?
-- if HU translations are provided, switch them on
-- ref and xrefelt are now the same, I think
-- feedbacktexts

import Common.Library
import ExerciseInfo
import Service.OpenMathSupport
import Text.OpenMath.Object
import Text.XML.Interface
import qualified Main.Revision as MR

import Data.Map((!))
import Data.Maybe
import Domain.LinearAlgebra
import Domain.Math.Derivative.Exercises
import Domain.Math.Equation.CoverUpExercise
import Domain.Math.Numeric.Exercises
import Domain.Math.Polynomial.Exercises
import Domain.Math.Polynomial.IneqExercises
import Domain.Math.Polynomial.RationalExercises
import Domain.Math.Power.Equation.Exercises
import Domain.Math.Power.Exercises

import Text.XML

--------------------------------------------------------------------------------
{- Global info; should probably be generated by the makefile.
-}
--------------------------------------------------------------------------------

today  :: String
today  =  "Today's date"

--------------------------------------------------------------------------------
{- Generate all files
-}
--------------------------------------------------------------------------------

generateallfiles :: IO ()
generateallfiles =
      do let version = MR.version
         let revision = MR.revision
         omdocexercisefile version revision linearExercise
         omdocexercisefile version revision linearMixedExercise
         omdocexercisefile version revision quadraticExercise
         omdocexercisefile version revision higherDegreeExercise
         omdocexercisefile version revision rationalEquationExercise
         omdocexercisefile version revision ineqLinearExercise
         omdocexercisefile version revision coverUpExercise
         omdocexercisefile version revision fractionExercise
         omdocexercisefile version revision findFactorsExercise
         omdocexercisefile version revision ineqQuadraticExercise
         omdocexercisefile version revision ineqHigherDegreeExercise
         omdocexercisefile version revision simplifyRationalExercise
         omdocexercisefile version revision quadraticNoABCExercise
         omdocexercisefile version revision quadraticWithApproximation
         omdocexercisefile version revision derivativeExercise
         omdocexercisefile version revision derivativePolyExercise
         omdocexercisefile version revision derivativeProductExercise
         omdocexercisefile version revision derivativeQuotientExercise
         omdocexercisefile version revision simplifyPowerExercise
         omdocexercisefile version revision powerOfExercise
         omdocexercisefile version revision nonNegBrokenExpExercise
         omdocexercisefile version revision calcPowerExercise
         omdocexercisefile version revision powerEqExercise
         omdocexercisefile version revision expEqExercise
         omdocexercisefile version revision logEqExercise
         omdocexercisefile version revision gramSchmidtExercise
         omdocexercisefile version revision linearSystemExercise
         omdocexercisefile version revision gaussianElimExercise
         omdocexercisefile version revision systemWithMatrixExercise
         recbookfile version revision
           [sourcefile linearExercise
           ,sourcefile linearMixedExercise
           ,sourcefile quadraticExercise
           ,sourcefile higherDegreeExercise
           ,sourcefile rationalEquationExercise
           ,sourcefile ineqLinearExercise
           ,sourcefile coverUpExercise
           ,sourcefile fractionExercise
           ,sourcefile findFactorsExercise
           ,sourcefile ineqQuadraticExercise
           ,sourcefile ineqHigherDegreeExercise
           ,sourcefile simplifyRationalExercise
           ,sourcefile quadraticNoABCExercise
           ,sourcefile quadraticWithApproximation
           ,sourcefile derivativeExercise
           ,sourcefile derivativePolyExercise
           ,sourcefile derivativeProductExercise
           ,sourcefile derivativeQuotientExercise
           ,sourcefile simplifyPowerExercise
           ,sourcefile powerOfExercise
           ,sourcefile nonNegBrokenExpExercise
           ,sourcefile calcPowerExercise
           ,sourcefile powerEqExercise
           ,sourcefile expEqExercise
           ,sourcefile logEqExercise
           ,sourcefile gramSchmidtExercise
           ,sourcefile linearSystemExercise
           ,sourcefile gaussianElimExercise
           ,sourcefile systemWithMatrixExercise
           ]
           [omdocexerciserefs linearExercise
           ,omdocexerciserefs linearMixedExercise
           ,omdocexerciserefs quadraticExercise
           ,omdocexerciserefs higherDegreeExercise
           ,omdocexerciserefs rationalEquationExercise
           ,omdocexerciserefs ineqLinearExercise
           ,omdocexerciserefs coverUpExercise
           ,omdocexerciserefs fractionExercise
           ,omdocexerciserefs findFactorsExercise
           ,omdocexerciserefs ineqQuadraticExercise
           ,omdocexerciserefs ineqHigherDegreeExercise
           ,omdocexerciserefs simplifyRationalExercise
           ,omdocexerciserefs quadraticNoABCExercise
           ,omdocexerciserefs quadraticWithApproximation
           ,omdocexerciserefs derivativeExercise
           ,omdocexerciserefs derivativePolyExercise
           ,omdocexerciserefs derivativeProductExercise
           ,omdocexerciserefs derivativeQuotientExercise
           ,omdocexerciserefs simplifyPowerExercise
           ,omdocexerciserefs powerOfExercise
           ,omdocexerciserefs nonNegBrokenExpExercise
           ,omdocexerciserefs calcPowerExercise
           ,omdocexerciserefs powerEqExercise
           ,omdocexerciserefs expEqExercise
           ,omdocexerciserefs logEqExercise
           ,omdocexerciserefs gramSchmidtExercise
           ,omdocexerciserefs linearSystemExercise
           ,omdocexerciserefs gaussianElimExercise
           ,omdocexerciserefs systemWithMatrixExercise
           ]

--------------------------------------------------------------------------------
{- Generating the recbook for the exercise collections
-}
--------------------------------------------------------------------------------

recbookfile :: String -> Int -> [Element] -> [Element] -> IO ()
recbookfile version revision sourcefiles exercisesrefs = do
  let filestring =
             xmldecl
          ++ activemathdtd
          ++ showXML
               (omdocelt
                  ""
                  "http://www.activemath.org/namespaces/am_internal"
                  [omgroupelt "" "http://www.mathweb.org/omdoc"
                    [omgroupelt "IdeasExercises" ""
                      [metadataelt "IdeasExercises-metadata"
                        (titleelts [EN,NL] ["Ideas Exercises collection","Ideas opgaven"])
                        -- versionelt version (show revision) -- apparently not allowed
                      ,omgroupelt "recbook_for_IdeasExercises" ""
                        (metadataelt ""
                          (titleelts [EN,NL] ["Complete Ideas Exercises Recbook","Recbook voor alle Ideas opgaven"]
                           ++
                           [dateelt "created" "2011-01-22"
                           ,dateelt "changed" today
                           ,creatorelt "aut" "Johan Jeuring"
                           ,sourceelt ""
                           ,formatelt "application/omdoc+xml"
                           -- ,extradataelt sourcefiles -- apparently not allowed
                           ]
                          )
                        :exercisesrefs
                        )
                      ]
                    ]
                  ]
               )
  writeFile (omdocpath ++ "RecBook_Exercises.omdoc") filestring
  writeFile (oqmathpath ++ "RecBook_Exercises.oqmath") filestring

sourcefile :: Exercise a -> Element
sourcefile ex =
  sourcefileelt
    "http://www.activemath.org/namespaces/am_internal"
    ("omdoc/" ++ show (exerciseId ex))
    "1293473065000" -- last modified; don't know why or if this has to be provided

omdocrefpath  :: String
omdocrefpath  =  ""

omdocexerciserefs :: Exercise a -> Element
omdocexerciserefs ex =
  let info             = mBExerciseInfo ! (exerciseId ex)
      langs            = langSupported info
      titleCmps        =  map (\l -> title info l) langs
      len              = length (examples ex)
      refs             = map (\i -> omdocrefpath  -- relative dir (the same right now)
                                ++  context info  -- filename
                                ++  "/"
                                ++  context info  -- exercise id
                                ++  show i)       -- and nr
                             [0..len-1]
      exercises        = map (`xrefelt` "exercise") refs
  in omgroupelt "" "" (metadataelt "" [titleeltMultLang langs titleCmps]:exercises)

--------------------------------------------------------------------------------
{- Generating an omdoc file for an exercise
-}
--------------------------------------------------------------------------------

{- -- For testing purposes
omdocpath :: String
omdocpath = "/Users/johanj/Documents/Research/ExerciseAssistants/Feedback/math-bridge/activemath/all/activemath-ideas/content/IdeasExercises/omdoc/"

oqmathpath :: String
oqmathpath = "/Users/johanj/Documents/Research/ExerciseAssistants/Feedback/math-bridge/activemath/all/activemath-ideas/content/IdeasExercises/oqmath/"
-}

-- -- For committing purposes
omdocpath :: String
omdocpath = "/Users/johanj/Documents/Research/ExerciseAssistants/Feedback/math-bridge/private/Content/Intermediate/IdeasExercises/omdoc/"

oqmathpath :: String
oqmathpath = "/Users/johanj/Documents/Research/ExerciseAssistants/Feedback/math-bridge/private/Content/Intermediate/IdeasExercises/oqmath/"
--

omdocexercisefile :: (IsTerm a) => String -> Int -> Exercise a -> IO ()
omdocexercisefile version revision ex = do
  let info = mBExerciseInfo ! (exerciseId ex)
  let langs = langSupported info
  let titleTexts =  map (\l -> title info l) langs
  let filestring =
             xmldecl
          ++ activemathdtd
          ++ showXML
               (omdocelt
                  (context info ++ ".omdoc")
                  []
                  [metadataelt
                    ""
                    ([dateelt "created" "2011-01-22"
                     ,dateelt "changed" today
                     ] ++
                     titleelts langs titleTexts ++
                     [creatorelt "aut" "Johan Jeuring"
                     ,versionelt version (show revision)
                     ]
                    )
                  ,theoryelt (context info)
                             (omdocexercises ex)
                  ]
               )
  writeFile (omdocpath ++ context info ++ ".omdoc") filestring
  writeFile (oqmathpath ++ context info ++ ".oqmath") filestring

omdocexercises :: (IsTerm a) => Exercise a -> [Element]
omdocexercises ex = catMaybes $ zipWith make [(0::Int)..] (examples ex)
 where
   info = mBExerciseInfo ! (exerciseId ex)
   langs = langSupported info
   titleTexts =  map (\l -> title info l) langs
   make nr (dif, example) =
      fmap (makeElement . omobj2xml) (toOpenMath ex example)
    where
      makeElement omobj =
         omdocexercise
            (context info ++ show nr)
            (titleelts langs titleTexts)
            (if null (for info) then Nothing else Just (for info))
            (show dif)
            langs
            (map (\l -> cmp info l ++ (show omobj)) langs)
            "IDEASGenerator"
            "strategy"
            (problemStatement info)
            (context info)
            omobj

omdocexercise :: String
              -> [Element]
              -> Maybe String
              -> String
              -> [Lang]
              -> [String]
              -> String
              -> String
              -> String
              -> String
              -> Element
              -> Element
omdocexercise
    exerciseid
    titles
    maybefor
    difficulty
    langs
    cmps
    interaction_generatorname
    interaction_generatortype
    problemstatement
    ctxt
    task
  = exerciseelt
      exerciseid
      Nothing
      ([metadataelt
         ""
         (titles ++
          [formatelt "AMEL1.0"
          ,extradataelt
            (difficultyelt difficulty
            :case maybefor of
               Just for -> [relationelt for]
               Nothing  -> []
            )
          ]
         )
       ]
       ++
       cmpelts langs cmps
       ++
       [interaction_generatorelt
         interaction_generatorname
         interaction_generatortype
         [parameterelt "problemstatement" [Left problemstatement]
         ,parameterelt "context"          [Left ctxt]
         ,parameterelt "difficulty"       [Left difficulty]
         ,parameterelt "task"             [Right task]
         ]
       ]
      )

--------------------------------------------------------------------------------
{- XML elements for Omdoc.

Use inefficient string concatenation.
Probably use Text.XML.
-}
--------------------------------------------------------------------------------

activemathdtd  :: String
activemathdtd  =  "<!DOCTYPE omdoc SYSTEM \"../dtd/activemath.dtd\" []>\n"

cmpelts :: [Lang] -> [String] -> [Element]
cmpelts = zipWith (\l s -> cmpelt (show l) s)

cmpelt :: String  -> String -> Element
cmpelt lang cmp =
  Element { name        =  "CMP"
          , attributes  =  ["xml:lang" := lang]
          , content     =  [Left cmp]
          }

creatorelt :: String -> String -> Element
creatorelt role nm =
  Element { name         =  "Creator"
          , attributes   =  ["role" := role ]
          , content      =  [Left nm]
          }

dateelt :: String -> String -> Element
dateelt action date =
  Element { name         =  "Date"
          , attributes   =  ["action" := action ]
          , content      =  [Left date]
          }

difficultyelt :: String  -> Element
difficultyelt difficulty =
  Element { name        =  "difficulty"
          , attributes  =  ["value" := difficulty]
          , content     =  []
          }

extradataelt :: [Element] -> Element
extradataelt ls =
  Element { name        =  "extradata"
          , attributes  =  []
          , content     =  map Right ls
          }

exerciseelt :: String -> Maybe String -> [Element] -> Element
exerciseelt idattr maybefor ls =
  case maybefor of
    Nothing  -> Element { name        =  "exercise"
                        , attributes  =  ["id" := idattr]
                        , content     =  map Right ls
                        }
    Just for -> Element { name        =  "exercise"
                        , attributes  =  ["id" := idattr, "for" := for]
                        , content     =  map Right ls
                        }

formatelt :: String -> Element
formatelt format =
  Element { name        =  "Format"
          , attributes  =  []
          , content     =  [Left format]
          }

interaction_generatorelt :: String -> String -> [Element] -> Element
interaction_generatorelt interaction_generatorname interaction_generatortype ls =
  Element { name        =  "interaction_generator"
          , attributes  =  ["name" := interaction_generatorname
                           ,"type" := interaction_generatortype]
          , content     =  map Right ls
          }

metadataelt :: String -> [Element] -> Element
metadataelt identifier ls =
  Element { name        =  "metadata"
          , attributes  =  if null identifier
                           then []
                           else ["id" := identifier]
          , content     =  map Right ls
          }

omdocelt :: String -> String -> [Element] -> Element
omdocelt identifier namespace ls =
  Element { name         =  "omdoc"
          , attributes   =  if null namespace
                            then ["id" := identifier]
                            else if null identifier
                                 then ["xmlns:ami" := namespace]
                                 else ["id" := identifier
                                      ,"xmlns:ami" := namespace]
          , content      =  map Right ls
          }

omgroupelt :: String -> String -> [Element] -> Element
omgroupelt identifier namespace ls =
  Element { name         =  "omgroup"
          , attributes   = if null namespace && null identifier
                           then []
                           else if null namespace
                                then ["id" := identifier]
                                else if null identifier
                                     then ["xmlns" := namespace]
                                     else ["id" := identifier
                                          ,"xmlns" := namespace]
          , content      =  map Right ls
          }

omtextelt  :: String -> [Element] -> Element
omtextelt identifier ls =
  Element { name         =  "omtext"
          , attributes   =  ["id" := identifier]
          , content      =  map Right ls
          }

parameterelt :: String -> Content -> Element
parameterelt parametername ls =
  Element { name        =  "parameter"
          , attributes  =  ["name" := parametername]
          , content     =  ls
          }

refelt :: String -> Element
refelt ref =
  Element { name         =  "ref"
          , attributes   =  ["xref" := ref]
          , content      =  []
          }

relationelt :: String -> Element
relationelt for =
  Element { name         =  "relation"
          , attributes   =  ["type" := "for"]
          , content      =  [Right (refelt for)]
          }

sourceelt :: String -> Element
sourceelt source =
  Element { name         =  "Source"
          , attributes   =  []
          , content      =  if null source
                            then []
                            else [Left source]
          }

sourcefileelt :: String -> String -> String -> Element
sourcefileelt namespace filename lastmodified =
  Element { name         =  "sourcefile"
          , attributes   =  ["xmlns" := namespace
                            ,"path" := filename
                            ,"lastModified" := lastmodified]
          , content      =  []
          }

theoryelt  :: String -> [Element] -> Element
theoryelt identifier ls =
  Element { name         =  "theory"
          , attributes   =  ["id" := identifier]
          , content      =  map Right ls
          }

titleelt :: String -> Element
titleelt titletext =
  Element { name        =  "Title"
          , attributes  =  []
          , content     =  [Left titletext]
          }

titleeltlang :: Lang -> String -> Element
titleeltlang lang titletext =
  Element { name        =  "Title"
          , attributes  =  ["xml:lang" := show lang]
          , content     =  [Left titletext]
          }

titleelts :: [Lang] -> [String] -> [Element]
titleelts langs texts = zipWith titleeltlang langs texts

titleeltMultLang :: [Lang] -> [String] -> Element
titleeltMultLang langs texts =
  Element { name        =  "Title"
          , attributes  =  []
          , content     =  map Right (cmpelts langs texts)
          }

versionelt :: String -> String -> Element
versionelt version revision =
  Element { name        =  "Version"
          , attributes  =  ["number" := revision]
          , content     =  [Left version]
          }

xmldecl  :: String
xmldecl  =  "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"

xrefelt :: String -> String -> Element
xrefelt xref ami =
  Element { name         =  "ref"
          , attributes   =  ["xref" := xref
                            --,"ami:item-element-name" := ami -- apparently not allowed
                            ]
          , content      =  []
          }