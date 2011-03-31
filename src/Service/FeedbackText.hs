-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Service.FeedbackText 
   ( onefirsttext, submittext, derivationtext, submitHelper
   ) where

import Common.Library hiding (derivation)
import Common.Utils (fst3)
import Data.List
import Data.Maybe
import Service.ExercisePackage
import Service.State
import Service.Diagnose
import Service.BasicServices
import Service.FeedbackScript

------------------------------------------------------------
-- Services

derivationtext :: State a -> Either String [(String, Context a)]
derivationtext state = do
   script <- exerciseScript state
   xs     <- derivation Nothing state
   return (map (first (newRuleText script)) xs)

onefirsttext :: State a -> Maybe String -> Either String (Bool, String, State a)
onefirsttext state event =
   case onefirst state of
      Right (r, _, s) -> do
         script <- exerciseScript state
         let mtxt = fromContext (stateContext s) >>= useToRewrite script r state
             msg  = case mtxt of
                       Just txt | event /= Just "hint button" -> txt
                       _ -> "Use " ++ newRuleText script r
         return (True, msg, s)
      Left _ -> return (False, "Sorry, no hint available", state)
      
submittext :: State a -> String -> Either String (Bool, String, State a)
submittext old input = do
   script <- exerciseScript old
   case parser (exercise (exercisePkg old)) input of
      Left msg -> 
         return (False, result, old)
       where
         result | "(" `isPrefixOf` msg            = "Syntax error at " ++ msg
                | "Syntax error" `isPrefixOf` msg = msg
                | otherwise                       = "Syntax error: " ++ msg
      Right a  -> 
         return (submitHelper script old a)

-- Feedback messages for submit service (free student input). The boolean
-- indicates whether the student is allowed to continue (True), or forced 
-- to go back to the previous state (False)
submitHelper :: Script -> State a -> a -> (Bool, String, State a)
submitHelper script old a =
   case diagnose old a of
      Buggy r        -> ( False
                        , fromMaybe ""  (youRewroteInto old a) ++ 
                          feedbackBuggy env {recognized = Just r} script
                        , old
                        )
      NotEquivalent  -> ( False
                        , fromMaybe ""  (youRewroteInto old a) ++
                          feedbackNotEq env script
                        , old
                        )
      Expected _ s r -> (True, feedbackOk env {recognized = Just r} script, s)
      Similar _ s    -> (True, feedbackSame env script, s)
      Detour _ s r   -> (True, feedbackDetour env {recognized = Just r} script, s)
      Correct _ s    -> ( False
                        , fromMaybe ""  (youRewroteInto old a) ++ 
                          feedbackUnknown env script
                        , s
                        )
 where
   env = emptyEnvironment 
      { oldReady = Just (ready old)
      , expected = either (const Nothing) (Just . fst3) (onefirst old)
      }

------------------------------------------------------------
-- Helper functions

useToRewrite :: Script -> Rule (Context a) -> State a -> a -> Maybe String
useToRewrite script r old = rewriteIntoText True txt old
 where
   txt = "Use " ++ newRuleText script r ++ " to rewrite "

youRewroteInto :: State a -> a -> Maybe String
youRewroteInto = rewriteIntoText False "You rewrote "

rewriteIntoText :: Bool -> String -> State a -> a -> Maybe String
rewriteIntoText mode txt old a = do
   let ex = exercise (exercisePkg old)
   p <- fromContext (stateContext old)
   (p1, a1) <- difference ex mode p a 
   return $ txt ++ prettyPrinter ex p1 
         ++ " into " ++ prettyPrinter ex a1 ++ ". "

exerciseScript :: State a -> Either String Script
exerciseScript = 
   let msg = "No support for textual feedback"
   in maybe (fail msg) return . getScript . exercisePkg