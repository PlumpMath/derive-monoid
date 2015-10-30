{-# LANGUAGE TemplateHaskell, QuasiQuotes, RecordWildCards #-}
{-| (@.Internal@ modules may violate the PVP) -}
module Derive.Monoid.Internal where 
import Data.Semigroup 

import Language.Haskell.TH
import GHC.Exts (IsList (..))


data DeriveListConfig = DeriveListConfig
 { _makeEmptyName  :: String -> String 
 , _makeToListName :: String -> String 
 -- , _usePatternSynonyms :: Bool
 -- , _useSemigroup :: Bool
 }

data DeriveListNames = DeriveListNames
 { theType :: Name 
 , theConstructor :: Name 
 , theEmpty :: Name 
 , theToList :: Name 
 } deriving (Show,Eq,Ord)



{-| derives 'Semigroup', 'Monoid', 'IsList'.  
-}
deriveList :: Name -> Name -> DecsQ 
deriveList = deriveListWith defaultDeriveListConfig


{-| derives 'Semigroup', 'Monoid' only. 
-}
deriveMonoid :: Name -> Name -> DecsQ 
deriveMonoid = deriveMonoidWith defaultDeriveListConfig


{-| derives 'Semigroup' only. 
-}
deriveSemigroup :: Name -> Name -> DecsQ 
deriveSemigroup = deriveSemigroupWith defaultDeriveListConfig


{-| derives 'IsList' only.  
-}
deriveIsList :: Name -> Name -> DecsQ 
deriveIsList = deriveIsListWith defaultDeriveListConfig


{-| derives 'Semigroup', 'Monoid', 'IsList'.  
-}
deriveListWith :: DeriveListConfig -> Name -> Name -> DecsQ 
deriveListWith config@DeriveListConfig{..} theType theConstructor = fmap concat . traverse id $ 
 [ deriveSemigroup_ names 
 , deriveMonoid_ names 
 , deriveIsList_ names 
 , makeEmpty names 
 , makeToList names 
 ] 
 where 
 names = makeDeriveListNames config theType theConstructor 


{-| derives 'Semigroup', 'Monoid' only. 
-}
deriveMonoidWith :: DeriveListConfig -> Name -> Name -> DecsQ 
deriveMonoidWith config@DeriveListConfig{..} theType theConstructor = fmap concat . traverse id $ 
 [ deriveSemigroup_ names 
 , deriveMonoid_ names 
 , makeEmpty names 
 , makeToList names 
 ] 
 where 
 names = makeDeriveListNames config theType theConstructor 


{-| derives 'Semigroup' only. 
-}
deriveSemigroupWith :: DeriveListConfig -> Name -> Name -> DecsQ 
deriveSemigroupWith config@DeriveListConfig{..} theType theConstructor = fmap concat . traverse id $ 
 [ deriveSemigroup_ names 
 , makeToList names 
 ] 
 where 
 names = makeDeriveListNames config theType theConstructor 


{-| derives 'IsList' only.  
-}
deriveIsListWith :: DeriveListConfig -> Name -> Name -> DecsQ 
deriveIsListWith config@DeriveListConfig{..} theType theConstructor = fmap concat . traverse id $ 
 [ deriveIsList_ names 
 , makeToList names 
 ] 
 where 
 names = makeDeriveListNames config theType theConstructor 


{-| 

needs no constraints.
 
assumes 'makeToList'

-}
deriveSemigroup_ :: DeriveListNames -> DecsQ 
deriveSemigroup_ DeriveListNames{..} = do 
 [d| instance Semigroup $theTypeT where
       (<>) x y = $theConstructorE ($theToListE x <> $theToListE y) |]

 where 
 theTypeT = conT theType 
 theConstructorE = conE theConstructor 
 theToListE = varE theToList 


{-| 

needs no constraints.

assumes 'deriveSemigroup_', 'makeEmpty'

-}
deriveMonoid_ :: DeriveListNames -> DecsQ 
deriveMonoid_ DeriveListNames{..} = do 
 [d| instance Monoid $theTypeT where
      mempty = $theEmptyE
      mappend = (<>) |]

 where 
 theTypeT = conT theType 
 theEmptyE = varE theEmpty 


{-| 

needs no constraints.

assumes 'makeToList'

-}
deriveIsList_ :: DeriveListNames -> DecsQ 
deriveIsList_ DeriveListNames{..} = do 
 [d| instance IsList $theTypeT where
       type Item $theTypeT = $theTypeT
       fromList = $theConstructorE
       toList = $theToListE |]

 where 
 theTypeT = conT theType 
 theConstructorE = conE theConstructor 
 theToListE = varE theToList 


{-| `PatternSynonyms` won't work until <https://ghc.haskell.org/trac/ghc/ticket/8761> 

-}
makeEmpty :: DeriveListNames -> DecsQ
makeEmpty DeriveListNames{..} = return [signatureD, definitionD]
 where 

 signatureD = SigD theEmpty (ConT theType) 

 definitionD = FunD theEmpty [Clause [] (NormalB bodyE) []]

 bodyE = (ConE theConstructor `AppE` (ListE []))

-- makeEmpty :: DeriveListNames -> DecsQ
-- makeEmpty DeriveListNames{..} = patternQD 
--  where 
--  patternQD = [d|pattern $theEmptyQP = $theConstructorQE []|]  
--  theEmptyQP = return$ ConP theEmpty []
--  theConstructorQE = return$ ConE theConstructor

-- [d|pattern $theEmptyQP = $theConstructorQE []|] 


makeToList :: DeriveListNames -> DecsQ
makeToList DeriveListNames{..} = traverse id [signatureD, definitionD]
 where 

 signatureD = SigD theToList <$> [t|$theTypeT -> [$theTypeT]|]  

 definitionD = do
  tsN <- newName "ts"
  tN <- newName "t"
  return$ FunD theToList
   [ Clause [ConP theConstructor [VarP tsN]] (NormalB (VarE tsN))        [] 
   , Clause [VarP tN]                        (NormalB (ListE [VarE tN])) [] 
   ]

 theTypeT = conT theType 

-- [d|
--    $theListName :: $theType -> [$theType]
--    $theListName ($theConstructor ts) = ts
--    $theListName t = [t]
-- ]



{-| can debug 'deriveList' with:  

@
print $ makeDeriveListNames 'defaultDeriveListConfig' \'\'T \'C
@

-}
makeDeriveListNames :: DeriveListConfig -> Name -> Name -> DeriveListNames
makeDeriveListNames DeriveListConfig{..} theType theConstructor = DeriveListNames{..}
 where 
 theEmpty  = mkName $ _makeEmptyName  (nameBase theType) 
 theToList = mkName $ _makeToListName (nameBase theType) 


{-| by default, the functions generated for a type @"T"@ are @"emptyT"@ and @"toTList"@. 

-}
defaultDeriveListConfig :: DeriveListConfig 
defaultDeriveListConfig = DeriveListConfig{..}
 where
 _makeEmptyName = (\typename -> "empty"<>typename)
 _makeToListName  = (\typename -> "to"<>typename<>"List")
 -- _usePatternSynonyms = True
 -- _useSemigroup = True
