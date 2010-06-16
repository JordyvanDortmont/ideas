{-# OPTIONS -XGADTs #-}
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
-- Services using JSON notation
--
-----------------------------------------------------------------------------
module Service.ModeJSON (processJSON, jsonTuple) where

import Common.Context
import Common.Utils (Some(..), distinct, readM)
import Common.Exercise
import Common.Strategy (makePrefix)
import Text.JSON
import Service.Request
import Service.State
import qualified Service.Types as Tp
import Service.Types hiding (String)
import Service.Submit
import Service.Evaluator
import Service.ExercisePackage 
import Service.DomainReasoner
import Control.Monad
import Data.Maybe
import Data.Char

-- TODO: Clean-up code
extractExerciseId :: Monad m => JSON -> m Id
extractExerciseId json =
   case json of
      String s -> newIdM s
      Array [String _, String _, a@(Array _)] -> extractExerciseId a
      Array (String s:tl) | any p s -> extractExerciseId (Array tl)
      Array (hd:_) -> extractExerciseId hd
      _ -> fail "no code"
 where 
   p c = not (isAlphaNum c || isSpace c || c `elem` ".-")

processJSON :: String -> DomainReasoner (Request, String, String)
processJSON input = do
   json <- parseJSON input
   req  <- jsonRequest json
   vers <- getVersion
   resp <- jsonRPC json myHandler
   let out = show $ (if null vers then id else addVersion vers) (toJSON resp)
   return (req, out, "application/json")

addVersion :: String -> JSON -> JSON
addVersion version json = 
   case json of
      Object xs -> Object (xs ++ [info])
      _         -> json
 where
   info = ("version", String version)

jsonRequest :: Monad m => JSON -> m Request
jsonRequest json = do
   srv  <- case lookupM "method" json of
              Just (String s) -> return s
              _               -> fail "Invalid method"
   let a = (lookupM "params" json >>= extractExerciseId)
   enc  <- case lookupM "encoding" json of
              Nothing         -> return Nothing
              Just (String s) -> liftM Just (readEncoding s)
              _               -> fail "Invalid encoding"
   src  <- case lookupM "source" json of
              Nothing         -> return Nothing
              Just (String s) -> return (Just s)
              _               -> fail "Invalid source"
   return Request 
      { service    = srv
      , exerciseID = a
      , source     = src
      , dataformat = JSON
      , encoding   = enc
      }

myHandler :: JSON_RPC_Handler DomainReasoner
myHandler fun arg = do
   pkg  <- if fun == "exerciselist" 
           then return (Some (package emptyExercise))
           else extractExerciseId arg >>= findPackage
   srv  <- findService fun
   case jsonConverter pkg of
      Some conv -> do
         evalService conv srv arg

jsonConverter :: Some ExercisePackage -> Some (Evaluator JSON JSON)
jsonConverter (Some pkg) =
   Some (Evaluator (jsonEncoder (exercise pkg)) (jsonDecoder pkg))

jsonEncoder :: Exercise a -> Encoder JSON a
jsonEncoder ex = Encoder
   { encodeType  = encode (jsonEncoder ex)
   , encodeTerm  = return . String . prettyPrinter ex
   , encodeTuple = jsonTuple
   }
 where
   encode :: Encoder JSON a -> Type a t -> t -> DomainReasoner JSON
   encode enc serviceType a
      | length xs > 1 =
           liftM jsonTuple (mapM (\(b ::: t) -> encode enc t b) xs)
      | otherwise = 
           case serviceType of
              Tp.Tag s t | s == "Result" -> do
                 result <- isSynonym submitTypeSynonym (a ::: serviceType) 
                 encodeResult enc result
                         | s == "elem" -> 
                 encode enc t a
                         | s == "State" -> do
                 st <- isSynonym stateTypeSynonym (a ::: serviceType)
                 encodeState (encodeTerm enc) st
                 
              Tp.List t    -> liftM Array (mapM (encode enc t) a)
              Tp.Tag s t   -> liftM (\b -> Object [(s, b)]) (encode enc t a)
              Tp.Int       -> return (toJSON a)
              Tp.Bool      -> return (toJSON a)
              Tp.String    -> return (toJSON a)
              _            -> encodeDefault enc serviceType a
    where
      xs = tupleList (a ::: serviceType)
    
   tupleList :: TypedValue a -> [TypedValue a]
   tupleList (a ::: Tp.Iso _ f t)   = tupleList (f a ::: t)
   tupleList (p ::: Tp.Pair t1 t2) = 
      tupleList (fst p ::: t1) ++ tupleList (snd p ::: t2)
   tupleList tv = [tv]

jsonDecoder :: ExercisePackage a -> Decoder JSON a
jsonDecoder pkg = Decoder
   { decodeType     = decode (jsonDecoder pkg)
   , decodeTerm     = reader (exercise pkg)
   , decoderPackage = pkg
   }
 where
   reader :: Monad m => Exercise a -> JSON -> m a
   reader ex (String s) = either (fail . show) return (parser ex s)
   reader _  _          = fail "Expecting a string when reading a term"
 
   decode :: Decoder JSON a -> Type a t -> JSON -> DomainReasoner (t, JSON) 
   decode dec serviceType =
      case serviceType of
         Tp.Location -> useFirst decodeLocation
         Tp.Term     -> useFirst $ decodeTerm dec
         Tp.Rule     -> useFirst $ \x -> fromJSON x >>= getRule (decoderExercise dec)
         Tp.ExercisePkg -> \json -> case json of
                                       Array (String _:rest) -> return (decoderPackage dec, Array rest)
                                       _ -> return (decoderPackage dec, json)
         Tp.Int      -> useFirst $ \json -> case json of 
                                               Number (I n) -> return (fromIntegral n)
                                               _        -> fail "not an integer"
         Tp.String   -> useFirst $ \json -> case json of 
                                               String s -> return s
                                               _        -> fail "not a string"
         Tp.Tag s _ | s == "State" -> do 
            f <- equalM stateTp serviceType
            useFirst (liftM f . decodeState (decoderPackage dec) (decodeTerm dec))
         _ -> decodeDefault dec serviceType
   
   useFirst :: Monad m => (JSON -> m a) -> JSON -> m (a, JSON)
   useFirst f (Array (x:xs)) = do
      a <- f x
      return (a, Array xs)
   useFirst _ _ = fail "expecting an argument"

decodeLocation :: Monad m => JSON -> m [Int]
decodeLocation (String s) = readM s
decodeLocation _          = fail "expecting a string for a location"

--------------------------

encodeState :: Monad m => (a -> m JSON) -> State a -> m JSON
encodeState f st = do 
   theTerm <- f (term st)
   return $ Array
      [ String (showId (exercisePkg st))
      , String (maybe "NoPrefix" show (prefix st))
      , theTerm
      , encodeContext (getEnvironment (context st))
      ]

encodeContext :: Environment -> JSON
encodeContext env = Object (map f (keysEnv env))
 where
   f k = (k, String $ fromMaybe "" $ lookupEnv k env)

decodeState :: Monad m => ExercisePackage a -> (JSON -> m a) -> JSON -> m (State a)
decodeState pkg f (Array [a]) = decodeState pkg f a
decodeState pkg f (Array [String _code, String p, ce, jsonContext]) = do
   let ex = exercise pkg
   a    <- f ce 
   env  <- decodeContext jsonContext
   return State 
      { exercisePkg = pkg
      , prefix      = readM p >>= (`makePrefix` strategy ex)
      , context     = makeContext ex env a
      }
decodeState _ _ s = fail $ "invalid state" ++ show s

decodeContext :: Monad m => JSON -> m Environment
decodeContext (String "") = decodeContext (Object []) -- Being backwards compatible (for now)
decodeContext (Object xs) = foldM add emptyEnv xs
 where 
   add env (k, String s) = return (storeEnv k s env)       
   add _ _ = fail "invalid item in context"
decodeContext json = fail $ "invalid context: " ++ show json
   
encodeResult :: Encoder JSON a -> Result a -> DomainReasoner JSON
encodeResult enc result =
   case result of
      -- SyntaxError _ -> [("result", String "SyntaxError")]
      Buggy rs      -> return $ Object [("result", String "Buggy"), ("rules", Array $ map (String . showId) rs)]
      NotEquivalent -> return $ Object [("result", String "NotEquivalent")]   
      Ok rs st      -> do
         json <- encodeType enc stateTp st
         return $ Object [("result", String "Ok"), ("rules", Array $ map (String . showId) rs), ("state", json)]
      Detour rs st  -> do
         json <- encodeType enc stateTp st
         return $ Object [("result", String "Detour"), ("rules", Array $ map (String . showId) rs), ("state", json)]
      Unknown st    -> do
         json <- encodeType enc stateTp st
         return $ Object [("result", String "Unknown"), ("state", json)]

jsonTuple :: [JSON] -> JSON
jsonTuple xs = 
   case mapM f xs of 
      Just xs | distinct (map fst xs) -> Object xs
      _ -> Array xs
 where
   f (Object [p]) = Just p
   f _ = Nothing