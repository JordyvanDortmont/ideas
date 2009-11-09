-----------------------------------------------------------------------------
-- Copyright 2009, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- Locations in a strategy
--
-----------------------------------------------------------------------------
module Common.Strategy.Location 
   ( StrategyLocation, topLocation, nextLocation, downLocation
   , subTaskLocation, nextTaskLocation, parseStrategyLocation
   , StrategyOrRule, strategyLocations, subStrategy, addLocation
   ) where

import Common.Strategy.Abstract
import Common.Strategy.Core
import Common.Transformation
import Common.Uniplate
import Data.Char
import Data.Foldable (toList)
import Data.Sequence hiding (take)

-----------------------------------------------------------
--- Strategy locations

-- | A strategy location corresponds to a substrategy or a rule
newtype StrategyLocation = SL (Seq Int)
   deriving Eq

instance Show StrategyLocation where
   show (SL xs) = show (toList xs)

type StrategyOrRule a = Either (LabeledStrategy a) (Rule a)

topLocation :: StrategyLocation 
topLocation = SL empty

nextLocation :: StrategyLocation -> StrategyLocation
nextLocation (SL xs) =
   case viewr xs of
      EmptyR  -> topLocation -- invalid
      ys :> a -> SL (ys |> (a+1))

downLocation :: StrategyLocation -> StrategyLocation
downLocation (SL xs) = SL (xs |> 0)

-- old (current) and actual (next major rule) location
subTaskLocation :: StrategyLocation -> StrategyLocation -> StrategyLocation
subTaskLocation (SL xs) (SL ys) = SL (rec xs ys)
 where
   rec xs ys =
      case (viewl xs, viewl ys) of
         (i :< is, j :< js) 
            | i == j    -> i <| rec is js 
            | otherwise -> empty
         (_, j :< _)    -> singleton j
         _              -> empty

-- old (current) and actual (next major rule) location
nextTaskLocation :: StrategyLocation -> StrategyLocation -> StrategyLocation
nextTaskLocation (SL xs) (SL ys) = SL (rec xs ys)
 where
   rec xs ys =
      case (viewl xs, viewl ys) of
         (i :< is, j :< js)
            | i == j    -> i <| rec is js
            | otherwise -> singleton j
         _              -> empty

parseStrategyLocation :: String -> Maybe StrategyLocation
parseStrategyLocation s =
   case reads s of
      [(xs, rest)] | all isSpace rest -> Just (SL (fromList xs))
      _ -> Nothing

-- | Returns a list of all strategy locations, paired with the labeled 
-- substrategy or rule at that location

strategyLocations :: LabeledStrategy a -> [(StrategyLocation, StrategyOrRule a)]
strategyLocations = collect . addLocation . toCore . toStrategy
 where
   collect core = 
      [ (loc, result) 
      | Label (loc, l) s <- universe core 
      , Just result <- [make l s]
      ]
   
   make Nothing (Rule r) = Just (Right r)
   make (Just l) s = Just (Left (label l (catMaybeLabel (mapLabel snd s))))
   make _ _        = Nothing

-- | Returns the substrategy or rule at a strategy location. Nothing indicates that the location is invalid
subStrategy :: StrategyLocation -> LabeledStrategy a -> Maybe (StrategyOrRule a)
subStrategy loc = lookup loc . strategyLocations 
            
-- local helper functions that decorates interesting places with a 
-- strategy lcations (major rules, and labels)
addLocation :: Core l a -> Core (StrategyLocation, Maybe l) a
addLocation = fst . ($ topLocation) . rec
 where
   rec core =
      case core of
         -- Locations of interest
         Label l a -> \loc -> 
            let pair = (loc, Just l)
                rest = fst (rec a (downLocation loc))
            in (Label pair rest, nextLocation loc)
         Rule r | isMajorRule r -> \loc ->
            let pair = (loc, Nothing)
            in (Label pair (Rule r), nextLocation loc)
         -- Remaining (recursive) cases
         a :*: b   -> lift2 (:*:)  a b
         a :|: b   -> lift2 (:|:)  a b
         a :|>: b  -> lift2 (:|>:) a b
         Many a    -> lift1 Many a
         Rec n a   -> lift1 (Rec n) a
         _         -> \loc -> (noLabels core, loc) -- including Not
    where
      lift1 f a loc = 
         let (na, loc1) = rec a loc
         in (f na, loc1)
      lift2 f a b loc = 
         let (na, loc1) = rec a loc
             (nb, loc2) = rec b loc1
         in (f na nb, loc2)