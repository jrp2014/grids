{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
module Data.Grid.Examples.Intro where

import Data.Grid
import Data.Maybe
import Data.Functor.Compose
import Data.Coerce
import Data.Foldable
import Data.Functor.Rep
import GHC.TypeNats

simpleGrid :: Grid '[5, 5] Int
simpleGrid = generate id

coordGrid :: Grid '[5, 5] (Coord '[5, 5] 'C)
coordGrid = tabulate id


avg :: Foldable f => f Int -> Int
avg f | null f    = 0
      | otherwise = sum f `div` length f

mx :: Foldable f => f Int -> Int
mx = maximum

small :: Grid '[3, 3] Int
small = generate id

med :: Grid '[3, 3, 3] Int
med = generate id

big :: Grid '[5, 5, 5, 5] Int
big = generate id

threeByThree :: Grid '[3, 3] (Coord '[3, 3] ind)
threeByThree = fromJust $ fromNestedLists
  [ [(-1) :# (-1), (-1) :# 0, (-1) :# 1]
  , [0 :# (-1), 0 :# 0, 0 :# 1]
  , [1 :# (-1), 1 :# 0, 1 :# 1]
  ]

threeByThree' :: (Coord '[3, 3] C) -> Grid '[3, 3] (Coord '[3, 3] C)
threeByThree' = traverse (+) threeByThree

gauss
  :: ( Dimensions dims
     , Enum (Coord dims C)
     , (Neighboring (Coord '[3, 3] C) (Grid '[3, 3]))
     )
  => Grid dims Double
  -> Grid dims Double
gauss = safeAutoConvolute gauss'
 where
  gauss' :: Grid '[3, 3] (Maybe Double) -> Double
  gauss' g = (sum . Compose $ g) / fromIntegral (length (Compose g))

seeNeighboring :: Grid '[3, 3] a -> Grid '[3, 3] (Grid '[3, 3] (Maybe a))
seeNeighboring = safeAutoConvolute go
 where
  go :: Grid '[3, 3] (Maybe a) -> Grid '[3, 3] (Maybe a)
  go = coerce

coords :: Grid '[3, 3] (Coord '[3, 3] C)
coords = tabulate id

simpleGauss :: Grid '[3, 3] Double
simpleGauss = gauss (fromIntegral <$> small)

myGauss :: Grid '[9, 9] Double -> Grid '[9, 9] Double
myGauss = safeAutoConvolute @'[3, 3] gauss'
  where gauss' g = (sum . Compose $ g) / fromIntegral (length (Compose g))
