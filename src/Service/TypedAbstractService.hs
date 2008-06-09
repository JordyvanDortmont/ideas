-----------------------------------------------------------------------------
-- Copyright 2008, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- (...add description...)
--
-----------------------------------------------------------------------------
module Service.TypedAbstractService where

import qualified Common.Apply as Apply
import Common.Context  (Location, Context, inContext, location, currentFocus, Uniplate, setLocation)
import Common.Exercise (Exercise(..))
import Common.Strategy (Prefix, emptyPrefix, runPrefix, prefixToSteps, stepsToRules, runPrefixMajor, lastRuleInPrefix)
import Common.Transformation (Rule, name, isMajorRule, isBuggyRule)
import Common.Utils (safeHead)
import Data.Maybe
import System.Random
import Debug.Trace
import qualified Test.QuickCheck as QC

data State a = State 
   { exercise :: Exercise (Context a)
   , prefix   :: Maybe (Prefix (Context a))
   , term      :: Context a
   }

-- Note that in the typed setting there is no syntax error
data Result a = Buggy  [Rule (Context a)]   
              | NotEquivalent      
              | Ok     [Rule (Context a)] (State a)  -- equivalent
              | Detour [Rule (Context a)] (State a)  -- equivalent
              | Unknown                   (State a)  -- equivalent
          
-- result must be in the IO monad to access a standard random number generator
generate :: Exercise (Context a) -> Int -> IO (State a)
generate ex level = do 
   stdgen <- newStdGen
   case QC.generate 100 stdgen (generator ex) of
      a | suitableTerm ex a -> return State
             { exercise = ex 
             , prefix   = Just (emptyPrefix (strategy ex))
             , term     = a
             }
      _ -> generate ex level 

derivation :: State a -> [(Rule (Context a), Context a)]
derivation state = fromMaybe (error "derivation") $ do
   p0 <- prefix state
   (final, p1) <- safeHead (runPrefix p0 (term state))
   let steps = drop (length (prefixToSteps p0)) (prefixToSteps p1)
       rules = stepsToRules steps
       terms = let run x []     = [ [] | equality (exercise state) x final ]
                   run x (r:rs) = [ y:ys | y <- Apply.applyAll r x, ys <- run y rs ] 
               in fromMaybe [] $ safeHead (run (term state) rules)
       check = isMajorRule . fst
   return $ filter check $ zip rules terms

allfirsts :: State a -> [(Rule (Context a), Location, State a)]
allfirsts state = fromMaybe (error "allfirsts") $ do
   p0 <- prefix state
   let f (a, p1) = 
          [ (r, location a, state {term = a, prefix = Just p1})
          | Just r <- [lastRuleInPrefix p1], isMajorRule r
          ]
   return $ concatMap f $ runPrefixMajor p0 $ term state

onefirst :: State a -> (Rule (Context a), Location, State a)
onefirst = fromMaybe (error "onefirst") . safeHead . allfirsts

applicable :: Location -> State a -> [Rule (Context a)]
applicable loc state =
   let check r = Apply.applicable r (setLocation loc (term state))
   in filter check (ruleset (exercise state))

-- Two possible scenarios: either I have a prefix and I can return a new one (i.e., still following the 
-- strategy), or I return a new term without a prefix. A final scenario is that the rule cannot be applied
-- to the current term at the given location, in which case the request is invalid.
apply :: Rule (Context a) -> Location -> State a -> State a
apply r loc state = maybe applyOff applyOn (prefix state)
 where
   applyOn p = -- scenario 1: on-strategy
      fromMaybe applyOff $ safeHead
      [ s1 | (r1, loc1, s1) <- allfirsts state, name r == name r1, loc==loc1 ]
      
   applyOff  = -- scenario 2: off-strategy
      case Apply.apply r (setLocation loc (term state)) of
         Just new -> state { term=new }
         Nothing  -> error "apply"
       
ready :: State a -> Bool
ready state = finalProperty (exercise state) (term state)

stepsremaining :: State a -> Int
stepsremaining = length . derivation

-- For now, only one rule look-ahead (for buggy rules and for sound rules)
submit :: State a -> Context a -> Result a
submit state new
   | not (equivalence (exercise state) (term state) new) =
        case safeHead (filter isBuggyRule (findRules (exercise state) (term state) new)) of
           Just br -> Buggy [br]
           Nothing -> NotEquivalent
   | equality (exercise state) (term state) new =
        Ok [] state
   | otherwise =
        maybe applyOff applyOn (prefix state)

 where
   applyOn p = -- scenario 1: on-strategy
      fromMaybe applyOff $ safeHead
      [ Ok [r1] s1 | (r1, loc1, s1) <- allfirsts state, equality (exercise state) new (term s1) ]      
   
   applyOff = -- scenario 2: off-strategy
      let newState = state { term=new }
      in case safeHead (filter (not . isBuggyRule) (findRules (exercise state) (term state) new)) of
              Just r  -> Detour [r] newState
              Nothing -> Unknown newState
   
-- local helper-function
findRules :: Exercise a -> a -> a -> [Rule a]
findRules ex old new = 
   filter (maybe False (equality ex new) . (`Apply.apply` old)) (ruleset ex)