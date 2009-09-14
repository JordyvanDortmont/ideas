-- Some buggy rules catching common misconceptions on the abc-formula
module Domain.Math.Polynomial.BuggyRules where

import Domain.Math.Expr
import Domain.Math.Data.Equation
import Domain.Math.Data.OrList
import Domain.Math.Polynomial.Views
import Domain.Math.Numeric.Views
import Common.View
import Common.Transformation
import Common.Traversable
import Control.Monad
import Domain.Math.Polynomial.Rules (makeSqrt)

abcBuggyRules :: [Rule (OrList (Equation Expr))]
abcBuggyRules = [ minusB, twoA, minus4AC, oneSolution ]

abcMisconception :: (String -> Rational -> Rational -> Rational -> [OrList (Equation Expr)])
                 -> Transformation (OrList (Equation Expr))
abcMisconception f = makeTransList "abc misconception" $ 
   onceJoinM $ \(lhs :==: rhs) -> do
      guard (rhs == 0)
      (x, (a, b, c)) <- matchM (polyNormalForm rationalView >>> second quadraticPolyView) lhs
      f x a b c
      
minusB :: Rule (OrList (Equation Expr))
minusB = buggyRule $ makeRule "abc misconception minus b" $ 
   abcMisconception $ \x a b c -> do
      let discr = makeSqrt (fromRational (b*b - 4 * a * c))
          f (?) buggy = 
             let minus = if buggy then id else negate
             in Var x :==: (minus (fromRational b) ? discr) / (2 * fromRational a)
      id $ 
         [ orList [ f (+) True,  f (-) True  ]
         , orList [ f (+) False, f (-) True  ]
         , orList [ f (+) True,  f (-) False ]
         ]
         
twoA :: Rule (OrList (Equation Expr))
twoA = buggyRule $ makeRule "abc misconception two a" $ 
   abcMisconception $ \x a b c -> do
      let discr = makeSqrt (fromRational (b*b - 4 * a * c))
          f (?) buggy = 
             let twice = if buggy then id else (2*)
             in Var x :==: (-fromRational b ? discr) / twice (fromRational a)
      id $ 
         [ orList [ f (+) True,  f (-) True  ]
         , orList [ f (+) False, f (-) True  ]
         , orList [ f (+) True,  f (-) False ]
         ]
         
minus4AC :: Rule (OrList (Equation Expr))
minus4AC = buggyRule $ makeRule "abc misconception minus 4ac" $ 
   abcMisconception $ \x a b c -> do
      let discr (?) = makeSqrt (fromRational ((b*b) ? (4 * a * c)))
          f (?) buggy = 
             let op = if buggy then (+) else (-)
             in Var x :==: (-fromRational b ? discr op) / (2 * fromRational a)
      id $ 
         [ orList [ f (+) True,  f (-) True  ]
         , orList [ f (+) False, f (-) True  ]
         , orList [ f (+) True,  f (-) False ]
         ]
         
oneSolution :: Rule (OrList (Equation Expr))
oneSolution = buggyRule $ makeRule "abc misconception one solution" $ 
   abcMisconception $ \x a b c -> do
      let discr = makeSqrt (fromRational (b*b - 4 * a * c))
          f (?) = Var x :==: (-fromRational b ? discr) / (2 * fromRational a)
      [ return $ f (+), return $ f (-) ]