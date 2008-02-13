{-# OPTIONS -fglasgow-exts #-}
module OpenMath.StrategyTable where

import Common.Context
import Common.Assignment
import Common.Unification
import Common.Strategy
import Common.Transformation
import Domain.LinearAlgebra (reduceMatrixAssignment, solveSystemAssignment)
import Domain.LinearAlgebra (Matrix, rows, matrix, makeMatrix, MatrixInContext, 
                             EqsInContext(..), equations, LinearExpr, getConstant, coefficientOf, var)
import Domain.LinearAlgebra.Equation (Equation, getLHS, getRHS)
import qualified Domain.LinearAlgebra.Equation as LA
import OpenMath.ObjectParser
import Control.Monad

type StrategyID = String

versionNr :: String
versionNr = "0.2.2"

data ExprAssignment = forall a . IsExpr a => ExprAssignment (Assignment (Context a))

data StrategyEntry = Entry 
   { strategyNr     :: String
   , exprAssignment :: ExprAssignment
   , functions      :: [String]
   }
 
entry :: IsExpr a => String -> Assignment (Context a) -> [String] -> StrategyEntry
entry nr a fs = Entry nr (ExprAssignment a) fs

strategyTable :: [StrategyEntry]
strategyTable =
   [ entry "2.5" reduceMatrixAssignment ["toReducedEchelon"]
   , entry "1.7" solveSystemAssignment  ["generalSolutionLinearSystem", "systemToEchelonWithEEO", "backSubstitutionSimple"]
   ]

instance IsExpr a => IsExpr (Matrix a) where
   toExpr   = Matrix . map (map toExpr) . rows
   fromExpr (Matrix xs) = do 
      rows <- mapM (mapM fromExpr) xs
      return $ makeMatrix rows
   fromExpr _ = Nothing
   
instance (Fractional a, IsExpr a) => IsExpr (LinearExpr a) where
   toExpr x =
      let op s e = (toExpr (coefficientOf s x) :*: Var s) :+: e
      in foldr op (toExpr $ getConstant x) (getVarsList x)
   fromExpr e =
      case e of
         Con n    -> Just (fromIntegral n)
         Var s    -> Just (var s)
         Negate x -> liftM negate (fromExpr x)
         x :+: y  -> binop (+) x y
         x :-: y  -> binop (-) x y
         x :*: y  -> guard (isCon x || isCon y) >> binop (*) x y
         x :/: y  -> guard (isCon y)            >> binop (/) x y
         _        -> Nothing
    where
      binop op x y = liftM2 op (fromExpr x) (fromExpr y)
      isCon e =
         case e of
            Con _    -> True
            Negate x -> isCon x
            x :+: y  -> isCon x && isCon y
            x :-: y  -> isCon x && isCon y
            x :*: y  -> isCon x && isCon y
            x :/: y  -> isCon x && isCon y
            _        -> False

instance IsExpr a => IsExpr (Equation a) where
   toExpr eq = toExpr (getLHS eq) :==: toExpr (getRHS eq)
   fromExpr (e1 :==: e2) = do
      x <- fromExpr e1
      y <- fromExpr e2
      return (x LA.:==: y) 
   fromExpr _ = Nothing