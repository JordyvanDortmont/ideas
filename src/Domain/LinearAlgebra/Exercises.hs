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
module Domain.LinearAlgebra.Exercises 
   ( gramSchmidtExercise, linearSystemExercise
   , gaussianElimExercise, systemWithMatrixExercise
   ) where

import Common.Apply
import Common.Context
import Common.Exercise
import Common.Transformation
import Control.Monad
import Domain.LinearAlgebra.EquationsRules
import Domain.LinearAlgebra.GramSchmidtRules
import Domain.LinearAlgebra.LinearSystem
import Domain.LinearAlgebra.Matrix
import Domain.LinearAlgebra.MatrixRules
import Domain.LinearAlgebra.Parser
import Domain.LinearAlgebra.Strategies
import Domain.LinearAlgebra.Vector
import Domain.Math.Data.Relation
import Domain.Math.Expr
import Domain.Math.Simplification
import Test.QuickCheck

gramSchmidtExercise :: Exercise (VectorSpace (Simplified Expr))
gramSchmidtExercise = makeExercise
   { exerciseId     = describe "Gram-Schmidt" $
                         newId "linalg.gramschmidt"
   , status         = Alpha
   , parser         = \s -> case parseVectorSpace s of
                              Right a  -> Right (fmap simplified a)
                              Left msg -> Left msg
   , prettyPrinter  = unlines . map show . vectors
   , equivalence    = \x y -> let f = length . filter (not . isZero) . vectors . gramSchmidt
                              in f x == f y
   , extraRules     = rulesGramSchmidt
   , isReady        = orthonormalList . filter (not . isZero) . vectors
   , strategy       = gramSchmidtStrategy
   , randomExercise = let f = simplified . fromInteger . (`mod` 25)
                      in simpleGenerator (liftM (fmap f) arbitrary)
   }

linearSystemExercise :: Exercise (Equations Expr)
linearSystemExercise = makeExercise
   { exerciseId     = describe "Solve Linear System" $
                         newId "linalg.linsystem"
   , status         = Stable
   , parser         = \s -> case parseSystem s of
                               Right a  -> Right (simplify a)
                               Left msg -> Left msg
   , prettyPrinter  = unlines . map show
   , equivalence    = \x y -> let f = fromContext . applyD linearSystemStrategy 
                                    . inContext linearSystemExercise . map toStandardForm
                              in case (f x, f y) of  
                                    (Just a, Just b) -> getSolution a == getSolution b
                                    _ -> False 
   , extraRules     = equationsRules
   , ruleOrdering   = ruleNameOrderingWith [showId ruleScaleEquation]
   , isReady        = inSolvedForm
   , strategy       = linearSystemStrategy
   , randomExercise = simpleGenerator (fmap matrixToSystem arbMatrix)
   }
   
gaussianElimExercise :: Exercise (Matrix Expr)
gaussianElimExercise = makeExercise
   { exerciseId     = describe "Gaussian Elimination" $ 
                         newId "linalg.gaussianelim"
   , status         = Stable
   , parser         = \s -> case parseMatrix s of
                               Right a  -> Right (simplify a)
                               Left msg -> Left msg
   , prettyPrinter  = ppMatrixWith show
   , equivalence    = \x y -> fmap simplified x === fmap simplified y
   , extraRules     = matrixRules
   , isReady        = inRowReducedEchelonForm
   , strategy       = gaussianElimStrategy
   , randomExercise = simpleGenerator arbMatrix
   }
 
systemWithMatrixExercise :: Exercise Expr
systemWithMatrixExercise = makeExercise
   { exerciseId     = describe "Solve Linear System with Matrix" $ 
                         newId "linalg.systemwithmatrix"
   , status         = Provisional
   , parser         = \s -> case (parser linearSystemExercise s, parser gaussianElimExercise s) of
                               (Right ok, _) -> Right $ toExpr ok
                               (_, Right ok) -> Right $ toExpr ok
                               (Left _, Left _) -> Left "Syntax error"
   , prettyPrinter  = \expr -> case (fromExpr expr, fromExpr expr) of
                                  (Just ls, _) -> (unlines . map show) (ls :: Equations Expr)
                                  (_, Just m)  -> ppMatrix (m :: Matrix Expr)
                                  _            -> show expr
   , equivalence    = \x y -> let f expr = case (fromExpr expr, fromExpr expr) of
                                              (Just ls, _) -> Just (ls :: Equations Expr)
                                              (_, Just m)  -> Just $ matrixToSystem (m :: Matrix Expr)
                                              _            -> Nothing
                              in case (f x, f y) of
                                    (Just a, Just b) -> equivalence linearSystemExercise a b
                                    _ -> False
   , extraRules     = map liftExpr equationsRules ++ map liftExpr (matrixRules :: [Rule (Context (Matrix Expr))])
   , isReady        = inSolvedForm . (fromExpr :: Expr -> Equations Expr)
   , strategy       = systemWithMatrixStrategy
   , randomExercise = simpleGenerator (fmap (toExpr . matrixToSystem) (arbMatrix :: Gen (Matrix Expr)))
   , testGenerator  = fmap (liftM toExpr) (testGenerator linearSystemExercise)
   }
 
--------------------------------------------------------------
-- Other stuff (to be cleaned up)
                  
instance Arbitrary a => Arbitrary (Vector a) where
   arbitrary   = liftM fromList $ oneof $ map vector [0..2]
instance CoArbitrary a => CoArbitrary (Vector a) where
   coarbitrary = coarbitrary . toList

instance Arbitrary a => Arbitrary (VectorSpace a) where
   arbitrary = do
      i <- choose (0, 3) -- too many vectors "disables" prime factorization
      j <- choose (0, 10 `div` i)
      xs <- replicateM i (liftM fromList $ replicateM j arbitrary)
      return $ makeVectorSpace xs
instance CoArbitrary a => CoArbitrary (VectorSpace a) where
   coarbitrary = coarbitrary . vectors

arbMatrix :: Num a => Gen (Matrix a)
arbMatrix = fmap (fmap fromInteger) arbNiceMatrix

instance Arbitrary a => Arbitrary (Matrix a) where
   arbitrary = do
      (i, j) <- arbitrary
      arbSizedMatrix (i `mod` 5, j `mod` 5)
instance CoArbitrary a => CoArbitrary (Matrix a) where
   coarbitrary = coarbitrary . rows
   
arbSizedMatrix :: Arbitrary a => (Int, Int) -> Gen (Matrix a)
arbSizedMatrix (i, j) = 
   do rows <- replicateM i (vector j)
      return (makeMatrix rows)

arbUpperMatrix :: (Enum a, Num a) => Gen (Matrix a)
arbUpperMatrix = do
   a <- oneof $ map return [-5 .. 5]
   b <- oneof $ map return [-5 .. 5]
   c <- oneof $ map return [-5 .. 5]
   return $ makeMatrix [[1, a, b], [0, 1, c], [0, 0, 1]]

arbAugmentedMatrix :: (Enum a, Num a) => Gen (Matrix a)
arbAugmentedMatrix = do
   a <- oneof $ map return [-5 .. 5]
   b <- oneof $ map return [-5 .. 5]
   c <- oneof $ map return [-5 .. 5]
   return $ makeMatrix [[1, 0, 0, 1], [a, 1, 0, 1], [b, c, 1, 1]]
   
arbNiceMatrix :: (Enum a, Num a) => Gen (Matrix a)
arbNiceMatrix = do
   m1 <- arbUpperMatrix
   m2 <- arbAugmentedMatrix
   return (multiply m1 m2)