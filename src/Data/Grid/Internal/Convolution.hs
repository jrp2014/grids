{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
module Data.Grid.Internal.Convolution where

import           Data.Grid.Internal.Grid
import           Data.Grid.Internal.Coord
import           Data.Grid.Internal.Nest
import           Data.Functor.Rep
import           GHC.TypeNats
import           Data.Kind
import           Control.Applicative
import           Data.Functor.Compose
import           Data.Foldable
import           Data.Coerce

import           Control.Comonad
import           Control.Comonad.Representable.Store
import           Data.Maybe
import           Data.Proxy

criticalError :: a
criticalError = error
  "Something went wrong, please report this issue to the maintainer of grids"

-- | Perform a computation based on the context surrounding a cell
-- Good for doing things like Linear Image Filters (e.g. gaussian blur) or
-- simulating Cellular Automata (e.g. Conway's game of life)
--
-- This function accepts a function which indicates what to do with
-- 'out-of-bounds' indexes, 'clampWindow', 'wrapWindow' and 'safeWindow'
-- are examples.
--
-- It also acccepts a transformation function which operates over the
-- functor created by the first parameter and collapses it down to a new
-- value for the cell at that position.
--
-- This function is best used with Type Applications to denote the desired
-- window size; the Grid passed to the given function contains the current cell
-- (in the middle) and all the surrounding cells.
--
-- Here's an example of computing the average of all neighbouring cells,
-- repeating values at the edge of the grid when indexes are out of bounds
-- (using 'clampWindow')
--
-- > gaussian :: (Dimensions dims) => Grid dims Double -> Grid dims Double
-- > gaussian = autoConvolute clampWindow avg
-- >  where
-- >   avg :: Grid '[3, 3] Double -> Double
-- >   avg g = sum g / fromIntegral (length g)
autoConvolute
  :: forall window dims f a b
   . ( Dimensions dims
     , Dimensions window
     , Functor f
     , Neighboring window
     )
  => (Grid window (Coord dims) -> f (Coord dims)) -- ^ Restrict out of bounds coordinates in some way. Use 'clampWindow', 'wrapWindow' or 'safeWindow'
  -> (f a -> b) -- ^ Collapse the context down to a value
  -> Grid dims a -- ^ Starting grid
  -> Grid dims b
autoConvolute restrict = convolute (restrict . window @window @dims)

-- | This is a fully generic version of 'autoConvolute' which allows
-- the user to provide a function which builds a context from the current
-- coord, then provides a collapsing function over the same functor.
convolute
  :: forall dims f a b
   . (Functor f, Dimensions dims)
  => (Coord dims -> f (Coord dims))  -- ^ Build a neighbouring context within a functor from the current coord
  -> (f a -> b) -- ^ Collapse the context to a single value
  -> Grid dims a -- ^ Starting grid
  -> Grid dims b
convolute selectWindow f g =
  let s = store (index g) criticalError
      convoluted :: Store (Grid dims) b
      convoluted     = extend (f . experiment (fmap roundTrip . selectWindow)) s
      (tabulator, _) = runStore convoluted
  in  tabulate tabulator
 where
  roundTrip :: Coord dims -> Coord dims
  roundTrip = toEnum . fromEnum

-- | Given a coordinate generate a grid of size 'window' filled with
-- coordinates surrounding the given coord. Mostly used internally
window
  :: forall window dims
   . (Neighboring window, Dimensions window)
  => Coord dims
  -> Grid window (Coord dims)
window = fromWindow . neighboring . toWindow
 where
  toWindow :: Coord dims -> Coord window
  toWindow = coerceCoordDims
  fromWindow :: Grid window (Coord window) -> Grid window (Coord dims)
  fromWindow = fmap coerceCoordDims

-- data Orth a =
--   Orth
--     { up :: a
--     , right :: a
--     , down :: a
--     , left :: a
--     } deriving (Eq, Show, Functor, Traversable, Foldable)

-- orthNeighbours :: Coord dims  -> Compose Orth Maybe (Coord dims )
-- orthNeighbours c = Compose
--   (   toMaybe
--   <$> traverse
--         (+)
--         Orth {up = 0 :# (-1), right = 1 :# 0, down = 0 :# 1, left = -1 :# 0}
--         c
--   )
--  where
--   toMaybe c@(x :# y) | not (inBounds x) || not (inBounds y) = Nothing
--                      | otherwise                            = Just c

-- orthFromList [up', right', down', left'] =
--   Orth {up = up, right = right', down = down', left = left'}

class Neighboring dims where
  neighbors :: Grid dims (Coord dims)

instance {-# OVERLAPPING #-} (KnownNat n) => Neighboring '[n]  where
  neighbors = fromList' . fmap (Coord . pure . subtract (numVals `div` 2)) . take numVals $ [0 .. ]
    where
      numVals = gridSize @'[n]

instance (KnownNat n, Neighboring ns) => Neighboring (n:ns) where
  neighbors = joinGrid (addCoord <$> currentLevelNeighbors)
    where
      addCoord :: Coord '[n]  -> Grid ns (Coord (n : ns) )
      addCoord c = appendC c <$> nestedNeighbors
      nestedNeighbors :: Grid ns (Coord ns )
      nestedNeighbors = neighbors
      currentLevelNeighbors :: Grid '[n] (Coord '[n] )
      currentLevelNeighbors = neighbors

neighboring :: (Dimensions dims, Neighboring dims) => Coord dims -> Grid dims (Coord dims)
neighboring c = (c +) <$> neighbors

-- | Use with 'autoConvolute'; Clamp out-of-bounds coordinates to the nearest in-bounds coord.
clampWindow
  :: (Dimensions dims) => Grid window (Coord dims) -> Grid window (Coord dims)
clampWindow = fmap clampCoord

-- | Use with 'autoConvolute'; Wrap out-of-bounds coordinates pac-man style to the other side of the grid
wrapWindow
  :: (Dimensions dims) => Grid window (Coord dims) -> Grid window (Coord dims)
wrapWindow = fmap wrapCoord

-- | Use with 'autoConvolute'; Out of bounds coords become 'Nothing'
safeWindow
  :: (Dimensions dims) => Grid window (Coord dims) -> Compose (Grid window) Maybe (Coord dims)
safeWindow = Compose . fmap wrap
  where
    wrap c | coordInBounds c = Just c
           | otherwise  = Nothing
