module Domain.Math.SExpr (SExpr, toExpr, simplifyExpr, simplify, hasSquareRoot) where

import Common.Utils (safeHead)
import Common.Context
import Domain.Math.Classes
import Domain.Math.Expr
import Domain.Math.Constrained
import Domain.Math.Rules
import Domain.Math.Rewriting
import Control.Monad
import Data.List
import Data.Ratio
import Data.Maybe
import Data.Monoid
import Test.QuickCheck

newtype SExpr = SExpr (Constrained (Con Expr) Expr)

instance Show SExpr where
   show = show . toExpr -- !!

instance Eq SExpr where
   x == y = toExpr x == toExpr y -- !!

instance Num SExpr where
   (+) = liftS2 (+)
   (*) = liftS2 (*)
   (-) = liftS2 (-)
   negate      = liftS negate
   fromInteger = make . fromInteger

instance Fractional SExpr where
   (/) = liftS2 (/)
   fromRational = make . fromRational
   
instance Floating SExpr where
   sqrt = liftS sqrt
   pi   = make pi
   
instance Symbolic SExpr where
   variable   = make . variable
   function s = liftSs (function s)
   
instance Arbitrary SExpr where
   arbitrary   = liftM (make . return) arbitrary -- !!
   coarbitrary = coarbitrary . toExpr -- !!
   
toExpr :: SExpr -> Expr -- !!!
toExpr (SExpr e) = fromConstrained e

simplifyExpr :: Expr -> SExpr
simplifyExpr = make . return

liftS  f (SExpr a)           = make $ f a
liftS2 f (SExpr a) (SExpr b) = make $ f a b
liftSs f xs = make $ f [ e | SExpr e <- xs ]

make :: Constrained (Con Expr) Expr -> SExpr
make = simplify . SExpr

-----------------------------------------------------------------------
-- Simplifications

simplify :: SExpr -> SExpr
simplify (SExpr c) = SExpr $ {-liftM rewriteGS-} c >>= fixpointM (transformM f)
 where
   f a = (return . constantPropagation) a >>= applyRules >>= (return . simplifySquareRoots)
            
constantPropagation :: Expr -> Expr
constantPropagation e =
   maybe e fromRational (exprToFractional e)

simplifySquareRoots :: Expr -> Expr
simplifySquareRoots e =
   case e of
      Sqrt (Con a) -> maybe e fromInteger (hasSquareRoot a)
      _ -> e

hasSquareRoot :: Integer -> Maybe Integer
hasSquareRoot n
   | r*r == n  = Just r
   | otherwise = Nothing
 where
   r = round $ sqrt $ fromIntegral n
 
pp = let SExpr x = sqrt ((0*(sqrt 13) / 0)) in proposition x
 
applyRules :: Expr -> Constrained (Con Expr) Expr
applyRules e = 
   fromMaybe (return e) $ safeHead [ constrain p >> return a | r <- rs, (a, p) <- matchM r e ]
 where
   rs = [ rule2 "Def. minus" $ \x y -> x-y ~> x+(-y)
        , ruleZeroPlus, ruleZeroPlusComm 
        , ruleZeroTimes, ruleZeroTimesComm, ruleOneTimes, ruleOneTimesComm
        , ruleInvNeg, ruleZeroNeg
        , ruleZeroDiv, ruleOneDiv
        , ruleSimplPlusNeg, ruleSimplPlusNegComm
        , ruleSimplDiv, ruleSimpleSqrtTimes
        , rule2 "Temp1" $ \x y -> x * (1/y) ~> x/y
--        , rule2 "Temp2" $ \x y -> (1/y) * x ~> x/y
        , rule3 "Temp3" $ \x y z -> (x/z) * (y/z) ~> (x*y)/(z*z)
        , rule3 "Temp4" $ \x y z -> (x/z) + (y/z) ~> (x+y)/z
        , rule2 "Temp5" $ \x y -> (x/y)/y ~> x/(y*y)
        
        -- , rule5 "Xtreme" $ \a b x y c -> a*(x+ negate (a*c)) + b*(y+negate (b*c)) ~> ((a*x)+(b*y))-((a*a+b*b)*c)
        
--        , rule5 "Xtreme" $ \a b c d e -> (a + (-(b*c)))+(d + (- (e*c))) ~> (a+d)-((b+e)*c)
--        , rule3 "TempD" $ \x y z -> x*(y + (-z)) ~> (x*y) - (x*z)
        
--        , rule3 "Temp5" $ \x y z -> (x/y)/z ~> x/(y*z)
--        , rule3 "Temp6" $ \x y z -> x/(y/z) ~> (x*z)/y
--        , rule2 "Temp7" $ \x y -> sqrt (x/y) ~> sqrt x / sqrt y
        ]

-- Gram-Schmidt view
data ViewGS = PlusGS ViewGS ViewGS | TimesGS Rational Integer

rewriteGS :: Expr -> Expr
rewriteGS e = maybe e (fromViewGS . sortAndMergeViewGS) (toViewGS e)

toViewGS :: Expr -> Maybe ViewGS
toViewGS = foldExpr (bin plus, bin times, bin min, unop neg, con, bin div, unop sqrt, err, const err)
 where
   err _ = fail "toMySqrt"
   bin  f a b = join (liftM2 f a b)
   unop f a = join (liftM f a)
   con n = return (TimesGS (fromIntegral n) 1)
   
   plus a b = return (PlusGS a b)   
   min a b  = bin plus (return a)  (neg b)
   neg a    = bin times (con (-1)) (return a)
   div a b  = bin times (return a) (recip b)
   
   times (PlusGS a b) c = bin plus (times a c) (times b c)
   times a (PlusGS b c) = bin plus (times a b) (times a c)
   times (TimesGS r1 n1) (TimesGS r2 n2) =
      case squareRoot (n1*n2) of
         Just (TimesGS r3 n3) -> return $ TimesGS (r1*r2*r3) n3
         _ -> Nothing
         
   recip (TimesGS r n) = return $ TimesGS (1 / (fromIntegral n*r)) n 
   recip _ = Nothing
   
   sqrt (TimesGS r 1) 
      | r2 == 1 = 
           squareRoot r1
      | otherwise =  
           bin div (unop sqrt $ con $ fromIntegral r1) (unop sqrt $ con $ fromIntegral r2)
    where (r1, r2) = (numerator r, denominator r)
   sqrt _ = Nothing
   
   squareRoot n = maybe (rec 1 n [2..20]) con (hasSquareRoot n) 
    where
      rec i n [] = return $ TimesGS (fromInteger i) n
      rec i n (x:xs)
         | n `mod` x2 == 0 = rec (i*x) (n `Prelude.div` x2) (x:xs)
         | otherwise       = rec i n xs
       where
         x2 = x*x
      
sortAndMergeViewGS :: ViewGS -> ViewGS
sortAndMergeViewGS = merge . sortBy cmp . collect
 where
   collect (PlusGS a b)  = collect a ++ collect b
   collect (TimesGS r n) = [(r, n)]
   
   merge ((r1, n1):(r2, n2):rest)
      | n1 == n2  = merge ((r1+r2, n1):rest)
      | otherwise = PlusGS (TimesGS r1 n1) (merge ((r2,n2):rest))
   merge [(r1, n1)] = TimesGS r1 n1
   
   cmp x y = snd x `compare` snd y

fromViewGS :: ViewGS -> Expr
fromViewGS (PlusGS a b)  = fromViewGS a + fromViewGS b
fromViewGS (TimesGS r n) = fromRational r * sqrt (fromIntegral n)

setS :: (Expr -> Expr) -> SExpr -> SExpr
setS _ (SExpr c) = SExpr (f c)
 where f :: Constrained c a -> Constrained c a
       f = id

{-
gsRules :: Expr -> Expr
gsRules (x :/: Sqrt y) = (x*sqrt y) / y
gsRules (Sqrt y :/: z) = (1/z) * Sqrt y
gsRules (Sqrt x :*: Sqrt y) = Sqrt (x*y)
gsRules (Sqrt x :*: y) = y*Sqrt x
gsRules (x :*: (y :*: z)) = (x*y)*z
gsRules (x :*: (y :+: z)) = (x*y)+(x*z)
gsRules a = a -}

{-
special :: Expr -> Expr
special e0 = fromMaybe e0 $ do 
   triples <- mapM f (collectPlus e0)
   guard (check triples)
   return $ partOne triples - (partTwo triples * partThree triples)
 where
   f (a1 :*: (x :+: Negate (a2 :*: c))) | a1==a2 = Just (a1, x, c)
   f _ = Nothing
   check (x:xs) = all ((==thd3 x) . thd3) xs
   thd3 (_, _, a) = a
   
   partOne   = foldr1 (+) . map (\(a,x,_) -> a*x)
   partTwo   = foldr1 (+) . map (\(a,_,_) -> a*a)
   partThree = thd3 . head -}
   