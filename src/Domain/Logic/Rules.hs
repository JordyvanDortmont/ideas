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
-- Rewrite rules in the logic domain (including all the rules from the 
-- DWA course)
--
-----------------------------------------------------------------------------
module Domain.Logic.Rules where

import Domain.Logic.Formula
import Common.Transformation
import Common.Rewriting
import Domain.Logic.Generator()
import Domain.Logic.GeneralizedRules
 
logicRules :: [Rule SLogic]
logicRules = concat 
   [ groupCommutativity, groupAssociativity, groupIdempotency
   , groupAbsorption, groupTrueProperties, groupFalseProperties, groupDoubleNegation
   , groupDeMorgan, groupImplicationEliminatinon, groupEquivalenceElimination, groupAdditional
   , groupDistributionOrOverAnd, groupDistributionAndOverOr
   , groupInverseDeMorgan,groupInverseDistr
   ]

-----------------------------------------------------------------------------
-- Grouping DWA rules

makeGroup :: String -> [Rule SLogic] -> [Rule SLogic]
makeGroup = map . addRuleToGroup

groupCommutativity, groupAssociativity, groupDistributionOrOverAnd, groupDistributionAndOverOr,groupIdempotency, 
   groupAbsorption, groupTrueProperties, groupFalseProperties, groupDoubleNegation,
   groupDeMorgan, groupImplicationEliminatinon, groupEquivalenceElimination :: [Rule SLogic]

groupCommutativity = makeGroup "Commutativity" 
   [ruleCommOr, ruleCommAnd]
groupAssociativity = makeGroup "Associativity"
   [ruleAssocOr, ruleAssocAnd]

groupIdempotency = makeGroup "Idempotency"
   [ruleIdempOr, ruleIdempAnd]
groupAbsorption = makeGroup "Absorption"
   [ruleAbsorpOr, ruleAbsorpAnd]
groupTrueProperties = makeGroup "True Properties"
   [ruleTrueZeroOr, ruleTrueZeroAnd, ruleComplOr, ruleNotTrue]
groupFalseProperties = makeGroup "False Properties"
   [ruleFalseZeroOr, ruleFalseZeroAnd, ruleComplAnd, ruleNotFalse]
groupDoubleNegation = makeGroup "Double Negation"
   [ruleNotNot]
groupDeMorgan = makeGroup "De Morgan" 
   [ruleDeMorganOr, ruleDeMorganAnd, generalRuleDeMorganOr, generalRuleDeMorganAnd ]
groupImplicationEliminatinon = makeGroup "Implication Elimination"
   [ruleDefImpl]
groupEquivalenceElimination = makeGroup "Equivalence Elimination"
   [ruleDefEquiv]
groupDistributionOrOverAnd = makeGroup "DistributionOrOverAnd"
   [generalRuleOrOverAnd, ruleOrOverAnd ]
groupDistributionAndOverOr = makeGroup "DistributionAndOverOr"
   [generalRuleAndOverOr, ruleAndOverOr ]
groupInverseDeMorgan = makeGroup "InverseDeMorgan" 
    [ inverseDeMorganOr, inverseDeMorganAnd]
groupInverseDistr = makeGroup "InverseDistr"
    [ inverseAndOverOr, inverseOrOverAnd]
   
-----------------------------------------------------------------------------
-- Commutativity

ruleCommOr :: Rule SLogic  
ruleCommOr = rule "CommOr" $
   \x y -> x :||: y  :~>  y :||: x

ruleCommAnd :: Rule SLogic 
ruleCommAnd = rule "CommAnd" $
   \x y -> x :&&: y  :~>  y :&&: x
   
-----------------------------------------------------------------------------
-- Associativity (implicit)

ruleAssocOr :: Rule SLogic
ruleAssocOr = minorRule $ rule "AssocOr" $
   \x y z -> (x :||: y) :||: z  :~>  x :||: (y :||: z)

ruleAssocAnd :: Rule SLogic
ruleAssocAnd = minorRule $ rule "AssocAnd" $
   \x y z -> (x :&&: y) :&&: z  :~>  x :&&: (y :&&: z)
   
-----------------------------------------------------------------------------
-- Distributivity

ruleAndOverOr :: Rule SLogic 

ruleAndOverOr = ruleList "AndOverOr"
   [ \x y z -> x :&&: (y :||: z)  :~>  (x :&&: y) :||: (x :&&: z)
   , \x y z -> (x :||: y) :&&: z  :~>  (x :&&: z) :||: (y :&&: z)
   ]

ruleOrOverAnd :: Rule SLogic 
ruleOrOverAnd = ruleList "OrOverAnd"
   [ \x y z -> x :||: (y :&&: z)  :~>  (x :||: y) :&&: (x :||: z)
   , \x y z -> (x :&&: y) :||: z  :~>  (x :||: z) :&&: (y :||: z)
   ]
   
-----------------------------------------------------------------------------
-- Idempotency

ruleIdempOr, ruleIdempAnd :: Rule SLogic 

ruleIdempOr = rule "IdempOr" $
   \x -> x :||: x  :~>  x

ruleIdempAnd = rule "IdempAnd" $
   \x -> x :&&: x  :~>  x

-----------------------------------------------------------------------------
-- Absorption

ruleAbsorpOr, ruleAbsorpAnd :: Rule SLogic 

ruleAbsorpOr = ruleList "AbsorpOr" 
   [ \x y -> x :||: (x :&&: y)  :~>  x
   , \x y -> x :||: (y :&&: x)  :~>  x
   , \x y -> (x :&&: y) :||: x  :~>  x
   , \x y -> (y :&&: x) :||: x  :~>  x
   ]
    
ruleAbsorpAnd = ruleList "AbsorpAnd"
   [ \x y -> x :&&: (x :||: y)  :~>  x 
   , \x y -> x :&&: (y :||: x)  :~>  x 
   , \x y -> (x :||: y) :&&: x  :~>  x 
   , \x y -> (y :||: x) :&&: x  :~>  x 
   ]

-----------------------------------------------------------------------------
-- True-properties

ruleTrueZeroOr, ruleTrueZeroAnd, ruleComplOr, ruleNotTrue :: Rule SLogic 

ruleTrueZeroOr = ruleList "TrueZeroOr"
   [ \x -> T :||: x  :~>  T
   , \x -> x :||: T  :~>  T
   ]

ruleTrueZeroAnd = ruleList "TrueZeroAnd"
   [ \x -> T :&&: x  :~>  x
   , \x -> x :&&: T  :~>  x
   ] 
 
ruleComplOr = ruleList "ComplOr"
   [ \x -> x :||: Not x  :~>  T
   , \x -> Not x :||: x  :~>  T
   ]

ruleNotTrue = rule "NotTrue" $
   Not T  :~>  F
   
-----------------------------------------------------------------------------
-- False-properties

ruleFalseZeroOr, ruleFalseZeroAnd, ruleComplAnd, ruleNotFalse :: Rule SLogic 

ruleFalseZeroOr = ruleList "FalseZeroOr"
   [ \x -> F :||: x  :~>  x
   , \x -> x :||: F  :~>  x
   ]
  
ruleFalseZeroAnd = ruleList "FalseZeroAnd"
   [ \x -> F :&&: x  :~>  F
   , \x -> x :&&: F  :~>  F
   ]
 
ruleComplAnd = ruleList "ComplAnd"
   [ \x -> x :&&: Not x  :~>  F
   , \x -> Not x :&&: x  :~>  F
   ]

ruleNotFalse = rule "NotFalse" $
   Not F  :~>  T

-----------------------------------------------------------------------------
-- Double negation

ruleNotNot :: Rule SLogic 
ruleNotNot = rule "NotNot" $
   \x -> Not (Not x)  :~>  x
   
-----------------------------------------------------------------------------
-- De Morgan

ruleDeMorganOr :: Rule SLogic 
ruleDeMorganOr = rule "DeMorganOr" $
   \x y -> Not (x :||: y)  :~>  Not x :&&: Not y

ruleDeMorganAnd :: Rule SLogic 
ruleDeMorganAnd = rule "DeMorganAnd" $
   \x y -> Not (x :&&: y)  :~>  Not x :||: Not y
   
-----------------------------------------------------------------------------
-- Implication elimination

ruleDefImpl :: Rule SLogic 
ruleDefImpl = rule "DefImpl" $
   \x y -> x :->: y  :~>  Not x :||: y
   
-----------------------------------------------------------------------------
-- Equivalence elimination

ruleDefEquiv :: Rule SLogic 
ruleDefEquiv = rule "DefEquiv" $
   \x y -> x :<->: y  :~>  (x :&&: y) :||: (Not x :&&: Not y)

-----------------------------------------------------------------------------
-- Additional rules, not in the DWA course

groupAdditional :: [Rule SLogic]
groupAdditional = makeGroup "Additional rules"
   [ ruleFalseInEquiv, ruleTrueInEquiv, ruleFalseInImpl, ruleTrueInImpl
   , ruleCommEquiv, ruleDefEquivImpls, ruleEquivSame, ruleImplSame
   ]

ruleFalseInEquiv :: Rule SLogic 
ruleFalseInEquiv = ruleList "FalseInEquiv"
   [ \x -> F :<->: x  :~>  Not x
   , \x -> x :<->: F  :~>  Not x
   ]
   
ruleTrueInEquiv :: Rule SLogic 
ruleTrueInEquiv = ruleList "TrueInEquiv"
   [ \x -> T :<->: x  :~>  x
   , \x -> x :<->: T  :~>  x
   ]

ruleFalseInImpl :: Rule SLogic 
ruleFalseInImpl = ruleList "FalseInImpl"
   [ \x -> F :->: x  :~>  T
   , \x -> x :->: F  :~> Not x
   ]
   
ruleTrueInImpl :: Rule SLogic 
ruleTrueInImpl = ruleList "TrueInImpl"
   [ \x -> T :->: x  :~>  x
   , \x -> x :->: T  :~>  T
   ]
        
ruleCommEquiv :: Rule SLogic 
ruleCommEquiv = rule "CommEquiv" $
   \x y -> x :<->: y  :~>  y :<->: x

ruleDefEquivImpls :: Rule SLogic 
ruleDefEquivImpls = rule "DefEquivImpls" $
   \x y -> x :<->: y  :~>  (x :->: y) :&&: (y :->: x)

ruleEquivSame :: Rule SLogic 
ruleEquivSame = rule "EquivSame" $
   \x -> x :<->: x  :~>  T

ruleImplSame :: Rule SLogic 
ruleImplSame = rule "ImplSame" $
   \x -> x :->: (x::SLogic)  :~>  T