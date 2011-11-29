{-# LANGUAGE ExistentialQuantification #-}
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
-- A collection of general utility functions
--
-----------------------------------------------------------------------------
module Common.Utils
   ( Some(..), Typed(..), ShowString(..), readInt, readM
   , subsets, isSubsetOf
   , cartesian, distinct, allsame
   , safeHead, fixpoint
   , splitAtElem, splitsWithElem
   , useFixedStdGen, fst3, snd3, thd3, commaList
   ) where

import Data.Char
import Data.List
import Data.Maybe
import Data.Typeable
import System.Random

data Some f = forall a . Some (f a)

data Typed f = forall a . Typeable a => Typed (f a)

data ShowString = ShowString { fromShowString :: String }
   deriving (Eq, Ord)

instance Show ShowString where
   show = fromShowString

readInt :: String -> Maybe Int
readInt xs
   | null xs                = Nothing
   | any (not . isDigit) xs = Nothing
   | otherwise              = Just (foldl' (\a b -> a*10+ord b-48) 0 xs) -- '

readM :: (Monad m, Read a) => String -> m a
readM s = case reads s of
             [(a, xs)] | all isSpace xs -> return a
             _ -> fail ("no read: " ++ s)

subsets :: [a] -> [[a]]
subsets = foldr op [[]]
 where op a list = list ++ map (a:) list

isSubsetOf :: Eq a => [a] -> [a] -> Bool
isSubsetOf xs ys = all (`elem` ys) xs

cartesian :: [a] -> [b] -> [(a, b)]
cartesian as bs = [ (a, b) | a <- as, b <- bs ]

distinct :: Eq a => [a] -> Bool
distinct []     = True
distinct (x:xs) = all (/=x) xs && distinct xs

allsame :: Eq a => [a] -> Bool
allsame []     = True
allsame (x:xs) = all (==x) xs

{-# DEPRECATED safeHead "Use Data.Maybe.listToMaybe instead" #-}
safeHead :: [a] -> Maybe a
safeHead = listToMaybe

fixpoint :: Eq a => (a -> a) -> a -> a
fixpoint f = stop . iterate f
 where
   stop []           = error "Common.Utils: empty list"
   stop (x:xs)
      | x == head xs = x
      | otherwise    = stop xs

splitAtElem :: Eq a => a -> [a] -> Maybe ([a], [a])
splitAtElem c s =
   case break (==c) s of
      (xs, _:ys) -> Just (xs, ys)
      _          -> Nothing

splitsWithElem :: Eq a => a -> [a] -> [[a]]
splitsWithElem c s =
   case splitAtElem c s of
      Just (xs, ys) -> xs : splitsWithElem c ys
      Nothing       -> [s]

-- | Use a fixed standard "random" number generator. This generator is
-- accessible by calling System.Random.getStdGen
useFixedStdGen :: IO ()
useFixedStdGen = setStdGen (mkStdGen 280578) {- magic number -}

fst3 :: (a, b, c) -> a
fst3 (x, _, _) = x

snd3 :: (a, b, c) -> b
snd3 (_, x, _) = x

thd3 :: (a, b, c) -> c
thd3 (_, _, x) = x

{-# DEPRECATED commaList "Use Data.List.intercalate \", \" instead" #-}
commaList :: [String] -> String
commaList = intercalate ", "