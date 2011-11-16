{-# LANGUAGE GADTs, ExistentialQuantification #-}
-----------------------------------------------------------------------------
-- Copyright 2011, Open Universiteit Nederland. This file is distributed
-- under the terms of the GNU General Public License. For more information,
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- This module defines transformations. Given a term, a transformation returns 
-- a list of results (often a singleton list or the empty list). A 
-- transformation can be parameterized with one or more arguments. 
-- Transformations rules can be lifted to work on more complex domains with
-- the LiftView type class.
--
-----------------------------------------------------------------------------
module Common.Transformation
   ( -- * Transformations
     Transformation, HasTransformation(..)
   , makeTrans, makeTransG
     -- * Arguments
   , ArgDescr(..), defaultArgDescr, Argument(..), ArgValue(..), ArgValues
   , supply1, supply2, supply3
     -- * Recognizers
   , useRecognizer, useSimpleRecognizer, recognizer
   , supplyRecognizer, supplySimpleRecognizer
     -- * Extract information
   , getDescriptors, expectedArguments, getRewriteRules
     -- * QuickCheck generators
   , smartApply, smartGen
   ) where

import Common.Algebra.Field
import Common.Classes
import Common.Rewriting
import Common.Utils
import Common.View
import Control.Monad
import Data.Foldable (Foldable, toList)
import Data.Function
import Data.Maybe
import Test.QuickCheck

-----------------------------------------------------------
--- Transformations

-- | Abstract data type for representing transformations
data Transformation a where
   Function    :: (a -> [a]) -> Transformation a
   RewriteRule :: RewriteRule a -> (a -> [a]) -> Transformation a
   Abstraction :: ArgDescr b -> (a -> Maybe b) -> (b -> Transformation a) -> Transformation a
   LiftView    :: View a (b, c) -> Transformation b -> Transformation a
   Recognizer  :: (a -> a -> Maybe ArgValues) -> Transformation a -> Transformation a
   (:|:)       :: Transformation a -> Transformation a -> Transformation a
   (:*:)       :: Transformation a -> Transformation a -> Transformation a

instance SemiRing (Transformation a) where
   zero  = makeTrans (const Nothing)
   (<+>) = (:|:)
   one   = makeTrans Just
   (<*>) = (:*:)

instance Apply Transformation where
   applyAll trans a =
      case trans of
         Function f        -> f a
         RewriteRule _ f   -> f a
         Abstraction _ f g -> maybe [] (\b -> applyAll (g b) a) (f a)
         LiftView v t      -> [ build v (b, c) | (b0, c) <- matchM v a, b <- applyAll t b0  ]
         Recognizer _ t    -> applyAll t a
         t1 :|: t2         -> applyAll t1 a ++ applyAll t2 a
         t1 :*: t2         -> [ c | b <- applyAll t1 a, c <- applyAll t2 b ]

instance LiftView Transformation where
   liftViewIn = LiftView

-- | Turn a function (which returns its result in the Maybe monad) into a transformation
makeTrans :: (a -> Maybe a) -> Transformation a
makeTrans = makeTransG

-- | Turn a function (which returns a list of results) into a transformation
makeTransG :: Foldable f => (a -> f a) -> Transformation a
makeTransG f = Function (toList . f)

-----------------------------------------------------------
--- HasTransformation type class

class HasTransformation f where
   transformation :: f a -> Transformation a

instance HasTransformation Transformation where
   transformation = id

instance HasTransformation RewriteRule where
   transformation r = RewriteRule r (rewriteM r)

-----------------------------------------------------------
--- Arguments

-- | A data type for describing an argument of a parameterized transformation
data ArgDescr a = ArgDescr
   { labelArgument    :: String               -- ^ Label that is shown to the user when asked to supply the argument
   , defaultArgument  :: a                    -- ^ Default value that can be used
   , parseArgument    :: String -> Maybe a    -- ^ A parser
   , showArgument     :: a -> String          -- ^ A pretty-printer
   , termViewArgument :: View Term a          -- ^ Conversion to/from term
   , genArgument      :: Gen a                -- ^ An arbitrary argument generator
   }

-- | An argument descriptor, paired with a value
data ArgValue = forall a . ArgValue (ArgDescr a) a

-- | List of argument values
type ArgValues = [ArgValue]

instance Show ArgValue where
   show (ArgValue descr a) = labelArgument descr ++ "=" ++ showArgument descr a

instance Eq ArgValue where
   ArgValue d1 a1 == ArgValue d2 a2 =
      build (termViewArgument d1) a1 == build (termViewArgument d2) a2

-- | Constructor function for an argument descriptor that uses the Show and Read type classes
defaultArgDescr :: (Show a, Read a, IsTerm a, Arbitrary a) => String -> a -> ArgDescr a
defaultArgDescr descr a = ArgDescr descr a readM show termView arbitrary

-- | A type class for types which have an argument descriptor
class Arbitrary a => Argument a where
   makeArgDescr :: String -> ArgDescr a   -- ^ The first argument is the label of the argument descriptor

instance Argument Int where
   makeArgDescr = flip defaultArgDescr 0

-- | Parameterization with one argument using the provided label
supply1 :: Argument x
                  => String -> (a -> Maybe x)
                  -> (x -> Transformation a) -> Transformation a
supply1 = Abstraction . makeArgDescr

-- | Parameterization with two arguments using the provided labels
supply2 :: (Argument x, Argument y)
                   => (String, String) -> (a -> Maybe (x, y))
                   -> (x -> y -> Transformation a) -> Transformation a
supply2 (s1, s2) f t =
   supply1 s1 (fmap fst . f) $ \x ->
   supply1 s2 (fmap snd . f) $ t x

-- | Parameterization with three arguments using the provided labels
supply3 :: (Argument x, Argument y, Argument z)
                  => (String, String, String) -> (a -> Maybe (x, y, z))
                  -> (x -> y -> z -> Transformation a) -> Transformation a
supply3 (s1, s2, s3) f t =
   supply1 s1 (fmap fst3 . f) $ \x -> 
   supply1 s2 (fmap snd3 . f) $ \y -> 
   supply1 s3 (fmap thd3 . f) $ t x y

-- | Returns a list of argument descriptors
getDescriptors :: HasTransformation f => f a -> [Some ArgDescr]
getDescriptors = rec . transformation 
 where
   rec :: Transformation a -> [Some ArgDescr]
   rec trans =
      case trans of
         Function _           -> []
         RewriteRule _ _      -> []
         Abstraction args _ t -> Some args : rec (t (defaultArgument args))
         LiftView _ t         -> rec t
         Recognizer _ t       -> rec t
         t1 :|: t2            -> rec t1 ++ rec t2
         t1 :*: t2            -> rec t1 ++ rec t2

-- | Returns a list of pretty-printed expected arguments.
-- Nothing indicates that there are no such arguments (or the arguments
-- are not applicable for the current value)
expectedArguments :: HasTransformation f => f a -> a -> ArgValues
expectedArguments = rec . transformation
 where
   rec :: Transformation a -> a -> ArgValues
   rec trans a = 
      case trans of
         Function _      -> []
         RewriteRule _ _ -> []
         Abstraction args f t -> 
            case f a of
               Just b  -> ArgValue args b : rec (t b) a
               Nothing -> []
         LiftView v t -> 
            case match v a of
               Just (b, _) -> rec t b
               Nothing     -> []
         Recognizer _ t -> rec t a
         t1 :|: t2      -> rec t1 a ++ rec t2 a
         t1 :*: t2      -> rec t1 a ++ rec t2 a

{-
-- | Transform a rule and use a list of pretty-printed arguments. Nothing indicates that the arguments are
-- invalid (not parsable), or that the wrong number of arguments was supplied
useArgumentsTrans :: [String] -> Transformation a -> Maybe (Transformation a)
useArgumentsTrans list = rec
 where
   rec :: Transformation a -> Maybe (Transformation a)
   rec trans =
      case trans of
         Function _           -> Nothing
         RewriteRule _ _      -> Nothing
         Abstraction args _ g -> case list of
                                    [hd] -> fmap g (parseArgument args hd)
                                    _    -> Nothing
         LiftView v t         -> fmap (LiftView v) (rec t)
         Recognizer f t       -> fmap (Recognizer f) (rec t)
         Choice t1 t2         -> rec t1 `mplus` rec t2
-}
-----------------------------------------------------------
--- Rules

getRewriteRules :: HasTransformation f => f a -> [Some RewriteRule]
getRewriteRules = rec . transformation 
 where
   rec :: Transformation a -> [Some RewriteRule]
   rec trans =
      case trans of
         Function _        -> []
         RewriteRule rr _  -> [Some rr]
         Abstraction _ _ _ -> []
         LiftView _ t      -> rec t
         Recognizer _ t    -> rec t
         t1 :|: t2         -> rec t1 ++ rec t2
         t1 :*: t2         -> rec t1 ++ rec t2

recognizer :: HasTransformation f 
                => (a -> a -> Bool) -> f a -> a -> a -> Maybe ArgValues
recognizer eq f a b = rec (transformation f)
 where
   rec trans =
      case trans of
         Recognizer g t -> g a b `mplus` rec t
         t1 :|: t2      -> rec t1 `mplus` rec t2
         LiftView v t   -> msum
            [ recognizer (eq `on` g) t av bv
            | (av, c) <- matchM v a
            , (bv, _) <- matchM v b
            , let g z = build v (z, c)
            ]
          `mplus`
            noArg (any (`eq` b) (applyAll trans a)) -- is this really needed?
         _ -> noArg $ any (`eq` b) (applyAll trans a)
 
   noArg c = if c then Just [] else Nothing

useRecognizer :: (a -> a -> Maybe ArgValues) -> Transformation a -> Transformation a
useRecognizer f t = Recognizer f (transformation t)

useSimpleRecognizer :: (a -> a -> Bool) -> Transformation a -> Transformation a
useSimpleRecognizer p = useRecognizer $ \x y -> guard (p x y) >> return []

supplyRecognizer :: Argument x
        => (a -> a -> Maybe ArgValues) -> String -> (a -> Maybe x)
        -> (x -> Transformation a) -> Transformation a
supplyRecognizer rec s f = useRecognizer rec . supply1 s f

supplySimpleRecognizer :: Argument x
        => (a -> a -> Bool) -> String -> (a -> Maybe x)
        -> (x -> Transformation a) -> Transformation a
supplySimpleRecognizer eq s f = useSimpleRecognizer eq . supply1 s f

-----------------------------------------------------------
--- QuickCheck

smartGen :: HasTransformation f => f a -> a -> Maybe (Gen a)
smartGen = flip rec . transformation
 where
   rec :: a -> Transformation a -> Maybe (Gen a)
   rec a trans = 
      case trans of
         RewriteRule r _ -> return (smartGenerator r)
         LiftView v t -> do
            (b, c) <- matchM v a
            gen    <- rec b t
            return $ liftM (\n -> build v (n, c)) gen
         t1 :|: t2 -> recs [t1, t2]
         t1 :*: t2 -> recs [t1, t2]
         _ -> Nothing
    where
      recs ts = do
         case mapMaybe (rec a) ts of
            [] -> Nothing
            xs -> return (oneof xs)

smartApply :: HasTransformation f => f a -> a -> Gen [a]
smartApply t a =
   case transformation t of
      Abstraction args _ g -> do
         b <- genArgument args
         smartApply (g b) a
      trans -> return (applyAll trans a)