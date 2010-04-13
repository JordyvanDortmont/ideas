-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  alex.gerdes@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.Power.Exercises    
   ( simplifyPowerExercise
   , powerOfExercise 
   , nonNegExpExercise
   , calcPowerExercise
   ) where

import Common.Apply 
import Common.Context
import Common.Exercise
import Common.Navigator
import Common.Strategy hiding (not, replicate)
import Common.Utils (distinct)
import Common.View
import Control.Monad
import Data.List
import Data.Maybe
import Domain.Math.Examples.DWO3
import Domain.Math.Expr
import Domain.Math.Expr.Parser
import Domain.Math.Numeric.Views
import Domain.Math.Power.Rules
import Domain.Math.Power.Strategies
import Domain.Math.Power.Views
import Prelude hiding ( (^) )
import qualified Data.Map as M
import qualified Prelude

------------------------------------------------------------
-- Exercises

isSimplePower :: Expr -> Bool
isSimplePower (Sym s [Var _,y]) | s==powerSymbol = y `belongsTo` rationalView
isSimplePower _ = False

isPower :: View Expr a -> Expr -> Bool
isPower v expr = 
     let Just (_, xs) = match productView expr 
         f (Nat 1 :/: a) = g a
         f a = g a
         g (Sym s [Var _, a]) | s==powerSymbol = True && isJust (match v a)
         g (Sym s [x, Nat _]) | s==rootSymbol = isPower v x 
         g (Sqrt x) = g x
         g (Var _) = True
         g a = a `belongsTo` rationalView
     in distinct (concatMap collectVars xs) && all f xs
     
isPowerAdd :: Expr -> Bool
isPowerAdd expr =
  let Just xs = match sumView expr
  in all (isPower rationalView) xs && not (applicable calcPowerPlus expr)

normPowerNonNegRatio :: View Expr (M.Map String Rational, Rational) -- (Rational, M.Map String Rational)
normPowerNonNegRatio = makeView (liftM swap . f) (g . swap)
 where
     swap (x,y) = (y,x)
     f expr = 
        case expr of
           Sym s [a,b] 
              | s==powerSymbol -> do
                   (r, m) <- f a
                   if r==1 
                     then do
                       r2 <- match rationalView b
                       return (1, M.map (*r2) m)
                     else do
                       n <- match integerView b
                       if n >=0 
                         then return (r Prelude.^ n, M.map (*fromIntegral n) m)
                         else return (1/(r Prelude.^ abs n), M.map (*fromIntegral n) m)
              | s==rootSymbol ->
                  f (Sym powerSymbol [a, 1/b])
           Sqrt a -> 
              f (Sym rootSymbol [a,2])
           a :*: b -> do
             (r1, m1) <- f a
             (r2, m2) <- f b
             return (r1*r2, M.unionWith (+) m1 m2)
           a :/: b -> do
             (r1, m1) <- f a
             (r2, m2) <- f b
             guard (r2 /= 0)
             return (r1/r2, M.unionWith (+) m1 (M.map negate m2))
           Var s -> return (1, M.singleton s 1)
           Nat n -> return (toRational n, M.empty)
           Negate x -> do 
             (r, m) <- f x
             return (negate r, m)
           _ -> do
             r <- match rationalView expr
             return (fromRational r, M.empty)
     g (r, m) = 
       let xs = map f (M.toList m)
           f (s, r) = Var s .^. fromRational r
       in build productView (False, fromRational r : xs)


normPowerNonNegDouble :: View Expr (Double, M.Map String Rational)
normPowerNonNegDouble = makeView (liftM (roundof 6) . f) g
  where
    roundof n (x, m) = (fromIntegral (round (x * 10.0 ** n)) / 10.0 ** n, m)
    f expr = 
      case expr of
        Sym s [a,b] 
          | s==powerSymbol -> do
            (x, m) <- f a
            y      <- match rationalView b
            return (x ** (fromRational y), M.map (*y) m)
          | s==rootSymbol -> f (Sym powerSymbol [a, 1/b])
        Sqrt a -> f (Sym rootSymbol [a,2])
        a :*: b -> do
          (r1, m1) <- f a
          (r2, m2) <- f b
          return (r1*r2, M.unionWith (+) m1 m2)
        a :/: b -> do
          (r1, m1) <- f a
          (r2, m2) <- f b
          guard (r2 /= 0)
          return (r1/r2, M.unionWith (+) m1 (M.map negate m2))
        Var s -> return (1, M.singleton s 1)
        Negate x -> do 
          (r, m) <- f x
          return (negate r, m)
        _ -> do
          d <- match doubleView expr
          return (d, M.empty)
    g (r, m) = 
      let xs = map f (M.toList m)
          f (s, r) = Var s .^. fromRational r
      in build productView (False, fromDouble r : xs)


type PowerMap = (M.Map String Rational, Rational) -- (Rational, M.Map String Rational)

normPowerView' :: View Expr [PowerMap]
normPowerView' = makeView (liftM h . f) g
  where
    f = (mapM (match normPowerNonNegRatio) =<<) . match sumView
    g = build sumView . map (build normPowerNonNegRatio)
    h :: [PowerMap] -> [PowerMap]
    h = map (foldr1 (\(x,y) (_,q) -> (x,y+q))) . groupBy (\x y -> fst x == fst y) . sort

normPowerView :: View Expr (String, Rational)
normPowerView = makeView f g
 where
   f expr = 
        case expr of
           Sym s [x,y] 
              | s==powerSymbol -> do
                   (s, r) <- f x
                   r2 <- match rationalView y
                   return (s, r*r2)
              | s==rootSymbol -> 
                   f (x^(1/y))
           Sqrt x ->
              f (Sym rootSymbol [x, 2])
           Var s -> return (s, 1) 
           x :*: y -> do
             (s1, r1) <- f x
             (s2, r2) <- f y
             guard (s1==s2)
             return (s1, r1+r2)
           Nat 1 :/: y -> do
             (s, r) <- f y
             return (s, -r)
           x :/: y -> do
             (s1, r1) <- f x
             (s2, r2) <- f y
             guard (s1==s2)
             return (s1, r1-r2) 
           _ -> Nothing
             
   g (s, r) = Var s .^. fromRational r


powerExercise :: LabeledStrategy (Context Expr) -> Exercise Expr
powerExercise s = makeExercise 
   { status        = Provisional
   , parser        = parseExpr
   , navigation    = navigator                     
--   , equivalence   = viewEquivalent rationalView
   , strategy      = s
   }

simplifyPowerExercise :: Exercise Expr
simplifyPowerExercise = (powerExercise powerStrategy)
   { description  = "simplify expression (powers)"
   , exerciseCode = makeCode "math" "simplifyPower"
   , isReady      = isPowerAdd
   , isSuitable   = (`belongsTo` normPowerView')
   , equivalence  = viewEquivalent normPowerView'
   , examples     = concat $  simplerPowers ++ powers1 ++ powers2 
                           ++ negExp1 ++ negExp2
                           ++ normPower1 ++ normPower2 ++ normPower3
   }

powerOfExercise :: Exercise Expr
powerOfExercise = (powerExercise powerOfStrategy)
   { description  = "write as a power of a"
   , exerciseCode = makeCode "math" "powerOf"
   , isReady      = isSimplePower
   , isSuitable   = (`belongsTo` normPowerView)
   , equivalence  = viewEquivalent normPowerNonNegRatio -- normPowerView
   , examples     = concat $  powersOfA ++ powersOfX ++ brokenExp1' 
                           ++ brokenExp2 ++ brokenExp3 ++ normPower5'
                           ++ normPower6
   }

nonNegExpExercise :: Exercise Expr
nonNegExpExercise = (powerExercise nonNegExpStrategy)
   { description  = "write with a non-negative exponent"
   , exerciseCode = makeCode "math" "nonNegExp"
   , isReady      = isPower natView
   , isSuitable   = (`belongsTo` normPowerNonNegDouble)
   , equivalence  = viewEquivalent normPowerNonNegDouble
   , examples     = concat $  nonNegExp ++ nonNegExp2 ++ negExp4 ++ negExp5 
                           ++ brokenExp1 ++ normPower4' ++ normPower5
   }

calcPowerExercise :: Exercise Expr
calcPowerExercise = (powerExercise calcPowerStrategy)
   { description  = "simplify expression (powers)"
   , exerciseCode = makeCode "math" "calcPower"
   , isReady      = isPowerAdd
   , isSuitable   = (`belongsTo` normPowerView')
   , equivalence  = viewEquivalent normPowerView'
   , examples     = concat $ negExp3 ++ normPower3' ++ normPower4
   }

-- test stuff
{-
showDerivations ex es = 
  mapM_ (putStrLn . showDerivation ex) es

showAllDerivations ex = 
  mapM_ (\es -> putStrLn (replicate 80 '-') >> showDerivations ex es)
                        
a = Var "a"
b = Var "b"
-}