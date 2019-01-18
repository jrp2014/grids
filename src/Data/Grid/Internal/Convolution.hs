{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
module Data.Grid.Internal.Convolution where

import Data.Grid.Internal.Index
import Data.Grid.Internal.Types
import Data.Grid.Internal.Coord
import Data.Grid.Internal.Nest
import Data.Grid.Internal.Tagged
import Data.Functor.Rep
import GHC.TypeNats
import Data.Kind
import Control.Applicative
import Data.Functor.Compose
import Data.Foldable
import Data.Coerce

import Control.Comonad
import Control.Comonad.Representable.Store
import Data.Maybe
import Data.Proxy

criticalError :: a
criticalError = error
  "Something went wrong, please report this issue to the maintainer of grids"

autoConvolute
  :: forall ind window dims a b
   . ( Dimensions dims
     , Neighboring (Coord window ind) (Grid window)
     , Enum (Coord dims ind)
     , Enum (Coord dims C)
     , Num (Coord window ind)
     )
  => (Grid window a -> b)
  -> Grid dims a
  -> Grid dims b
autoConvolute = convolute @ind window

gconvolute
  :: forall ind dims f a b
   . (Functor f, Dimensions dims, Enum (Coord dims C), Enum (Coord dims ind))
  => (Coord dims ind -> f (Coord dims ind))
  -> (f a -> b)
  -> Grid dims a
  -> Grid dims b
gconvolute selectWindow f g =
  let
    s = store (index g) criticalError
    convoluted :: Store (Grid dims) b
    convoluted =
      extend (f . experiment (fmap roundTrip . selectWindow . coerceCoord)) s
    (tabulator, _) = runStore convoluted
  in
    tabulate tabulator
 where
  roundTrip :: Coord dims ind -> Coord dims C
  roundTrip = toEnum . fromEnum

convolute
  :: forall ind window dims a b
   . (Dimensions dims, Enum (Coord dims ind), Enum (Coord dims C))
  => (Coord dims ind -> Grid window (Coord dims ind))
  -> (Grid window a -> b)
  -> Grid dims a
  -> Grid dims b
convolute selectWindow f g = gconvolute selectWindow f g

safeConvolute
  :: forall ind window dims a b
   . (Dimensions dims, Enum (Coord dims ind), Enum (Coord dims C))
  => (Coord dims ind -> Grid window (Coord dims ind))
  -> (Grid window (Maybe a) -> b)
  -> Grid dims a
  -> Grid dims b
safeConvolute selectWindow f = gconvolute (restrict . selectWindow)
                                          (f . getCompose)
 where
  restrict
    :: Grid window (Coord dims ind)
    -> Compose (Grid window) Maybe (Coord dims ind)
  restrict = Compose . fmap go
   where
    go b | coordInBounds b = Just b
         | otherwise       = Nothing

safeAutoConvolute
  :: forall window dims a b
   . ( Dimensions dims
     , Neighboring (Coord window C) (Grid window)
     , Num (Coord window C)
     , Enum (Coord dims C)
     )
  => (Grid window (Maybe a) -> b)
  -> Grid dims a
  -> Grid dims b
safeAutoConvolute = safeConvolute @C window

window
  :: forall window dims ind
   . (Neighboring (Coord window ind) (Grid window), Num (Coord window ind))
  => Coord dims ind
  -> Grid window (Coord dims ind)
window = fromWindow . neighboring . toWindow
 where
  toWindow :: Coord dims ind -> Coord window ind
  toWindow = coerceCoordDims
  fromWindow :: Grid window (Coord window ind) -> Grid window (Coord dims ind)
  fromWindow = fmap coerceCoordDims

-- data Orth a =
--   Orth
--     { up :: a
--     , right :: a
--     , down :: a
--     , left :: a
--     } deriving (Eq, Show, Functor, Traversable, Foldable)

-- orthNeighbours :: Coord dims ind -> Compose Orth Maybe (Coord dims ind)
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

class Neighboring c g where
  neighbors :: g c

instance {-# OVERLAPPING #-} (KnownNat n, Enum (Index n ind)) => Neighboring (Coord '[n] ind) (Grid '[n]) where
  neighbors = fromList' . fmap toEnum . fmap (subtract (numVals `div` 2)) . take numVals $ [0 .. ]
    where
      numVals = inhabitants @(Coord '[n] ind)

instance (KnownNat n, Enum (Index n ind), Neighboring (Coord ns ind) (Grid ns)) => Neighboring (Coord (n:ns) ind) (Grid (n:ns)) where
  neighbors = joinGrid (addCoord <$> currentLevelNeighbors)
    where
      -- addCoord :: (Coord '[n] ind) -> Grid '[n] (Grid ns (Coord (n:ns) ind))
      addCoord (Coord i) = (i :#) <$> nestedNeighbors
      nestedNeighbors :: Grid ns (Coord ns ind)
      nestedNeighbors = neighbors
      currentLevelNeighbors :: Grid '[n] (Coord '[n] ind)
      currentLevelNeighbors = neighbors

neighboring :: (Num c, Neighboring c (Grid dims)) => c -> Grid dims c
neighboring c = (c +) <$> neighbors


-- -- instance {-# OVERLAPPABLE #-} (Integral x) => Collapsable x where
-- --   collapse = pure . fromIntegral
-- --   expand [] = error "not enough values to expand"
-- --   expand [x] = fromIntegral x
-- --   expand _ = error "too many values to expand"

-- -- instance (Num x, Collapsable x, Collapsable xs) => Collapsable (x :# xs) where
-- --   collapse (x :# xs) = collapse x ++ collapse xs
-- --   expand (x:xs) = fromIntegral x :# expand xs
-- --   expand _ = error "not enough values to expand"