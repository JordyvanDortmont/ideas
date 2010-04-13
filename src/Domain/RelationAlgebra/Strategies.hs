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
module Domain.RelationAlgebra.Strategies (toCNF) where

import Domain.RelationAlgebra.Rules
import Domain.RelationAlgebra.Formula
import Common.Context
import Common.Strategy
import Common.Transformation
import Prelude hiding (repeat)

toCNF :: LabeledStrategy (Context RelAlg)
toCNF = label "To CNF" $ 
   repeat $  label "step1" step1
          |> label "step2" step2
          |> label "step3" step3
 where
   step1 = topDown $ useRules $
      [ ruleRemCompl, ruleRemRedunExprs, ruleDoubleNegation
      , ruleIdempOr, ruleIdempAnd, ruleAbsorp, ruleAbsorpCompl
      ] ++ invRules
   step2 = topDown $ useRules 
      [ ruleCompOverUnion, ruleAddOverIntersec, ruleDeMorganOr, ruleDeMorganAnd
      , ruleNotOverComp, ruleNotOverAdd
      ]
   step3 = somewhere $ liftToContext 
      ruleUnionOverIntersec

-- local helper-function
useRules :: [Rule RelAlg] -> Strategy (Context RelAlg)
useRules = alternatives . map liftToContext
   


   
   
