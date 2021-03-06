{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLists #-}
module Data.Grid.Examples.Conway where

import Data.Grid
import Data.Foldable
import Data.List

rule :: Grid '[3, 3] Bool -> Bool
rule g = (currentCellAlive && livingNeighbours == 2) || livingNeighbours == 3
 where
  currentCellAlive = g `index` Coord [1, 1] -- Get the center cell
  livingNeighbours =
    (if currentCellAlive then subtract 1 else id) . length . filter id $ toList
      g

step :: (Dimensions dims) => Grid dims Bool -> Grid dims Bool
step = autoConvolute wrapWindow rule

glider :: [Coord '[10, 10]]
glider = Coord <$> [[0, 1], [1, 2], [2, 0], [2, 1], [2, 2]]

start :: Grid '[10, 10] Bool
start = tabulate (`elem` glider)

simulate :: Int -> Grid '[10, 10] Bool
simulate = (iterate step start !!)

showBool :: Bool -> Char
showBool True  = '#'
showBool False = '.'

showGrid :: (Dimensions '[x, y]) => Grid '[x, y] Bool -> String
showGrid = intercalate "\n" . toNestedLists . fmap showBool
