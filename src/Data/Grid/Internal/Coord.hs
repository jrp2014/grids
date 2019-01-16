{-# LANGUAGE DataKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeFamilyDependencies #-}

module Data.Grid.Internal.Coord where

import           Data.Grid.Internal.Mod
import           Data.Grid.Internal.Tagged
import           Data.Grid.Internal.Clamp
import           Data.Grid.Internal.Dims

import           GHC.TypeNats                      hiding ( Mod )
import           Data.Proxy
import           Data.Finite
import           Data.Kind

data Ind = Ordinal | Modular | Clamped | Simple | Unsafe | Tag

-- | Used for constructing arbitrary depth coordinate lists 
-- e.g. @('Finite' 2 ':#' 'Finite' 3)@
data x :# y = x :# y
  deriving (Show, Eq, Ord)

infixr 9 :#

instance (Num x, Num y) => Num (x :# y) where
  (x :# y) + (x' :# y') = (x + x') :# (y + y')
  a - b = a + (-b)
  (x :# y) * (x' :# y') = (x * x') :# (y * y')
  abs (x :# y) = abs x :# abs y
  signum (x :# y) = signum x :# signum y
  fromInteger n = error "fromInteger is not possible for (:#)"
  negate (x :# y) = negate x :# negate y

class AsIndex c (n :: Nat) where
  toIndex :: Proxy n -> Int -> c
  fromIndex :: Proxy n -> c -> Int

instance (KnownNat n) => AsIndex (Finite n) n where
  toIndex _ = fromIntegral
  fromIndex _ = fromIntegral

instance (KnownNat n) => AsIndex (Mod n) n where
  toIndex _ = newMod
  fromIndex _ = unMod

instance (KnownNat n) => AsIndex (Tagged n) n where
  toIndex _ = Tagged
  fromIndex _ = unTagged


instance (KnownNat n) => AsIndex (Clamp n) n where
  toIndex _ = newClamp
  fromIndex _ = unClamp

instance AsIndex Int n where
  toIndex _ = id
  fromIndex _ = id

instance {-# OVERLAPPABLE #-} (Integral i) => AsIndex i n where
  toIndex _ = fromIntegral
  fromIndex _ = fromIntegral

class AsCoord c (dims :: [Nat]) where
  toCoord :: Proxy dims -> Int -> c
  fromCoord :: Proxy dims -> c -> Int

instance (KnownNat x) => AsCoord [Int] '[x] where
  toCoord _ n =
    if n >= fromIntegral (natVal (Proxy @x))
                       then error $ "coordinate out of bounds: " ++ show n
                       else [n]
  fromCoord _ [n] = if n >= fromIntegral (natVal (Proxy @x))
                       then error $ "coordinate out of bounds: " ++ show n
                       else n
  fromCoord _ _ = error "coordinate mismatch"

instance (KnownNat x, KnownNat y, Sizeable xs, AsCoord [Int] (y:xs)) => AsCoord [Int] (x:y:xs) where
  toCoord _ n = if firstCoord >= fromIntegral (natVal (Proxy @x))
                   then error ("coordinate out of bounds: " ++ show n)
                   else firstCoord : toCoord (Proxy @(y:xs)) remainder
    where
      firstCoord = n `div` fromIntegral (gridSize (Proxy @(y:xs)))
      remainder = n `mod` gridSize (Proxy @(y:xs))
  fromCoord _ (x : ys) = if x >= fromIntegral (natVal (Proxy @x))
                   then error ("coordinate out of bounds: " ++ show x)
                   else firstPart + rest
      where
        firstPart = x * gridSize (Proxy @(y:xs))
        rest = fromCoord (Proxy @(y:xs)) ys
  fromCoord _ _ = error "coordinate mismatch"

instance AsCoord () '[] where
  toCoord _ _ = ()
  fromCoord _ () = 0

instance {-# OVERLAPPABLE #-} (AsIndex c n) => AsCoord c '[n] where
  toCoord _ = toIndex (Proxy @n)
  fromCoord _ = fromIndex (Proxy @n)

-- This instance is unnecessarily complicated to prevent overlapping instances
instance (KnownNat y, Sizeable xs, AsIndex xInd x, AsCoord xsCoord (y:xs)) => AsCoord (xInd :# xsCoord) (x:y:xs) where
  toCoord _ n = firstCoord :# toCoord (Proxy @(y:xs)) remainder
    where
      firstCoord = toIndex (Proxy @x) (n `div` fromIntegral (gridSize (Proxy @(y:xs))))
      remainder = n `mod` gridSize (Proxy @(y:xs))
  fromCoord _ (x :# ys) =
     toIndex (Proxy @x) (firstPart + rest)
      where
        firstPart = fromIndex (Proxy @x) x * gridSize (Proxy @(y:xs))
        rest = fromCoord (Proxy @(y:xs)) ys

-- | The coordinate type for a given dimensionality
--
-- > Coord [2, 3] == Finite 2 :# Finite 3
-- > Coord [4, 3, 2] == Finite 4 :# Finite 3 :# Finite 2
type family Coord (ind :: Ind) (dims :: [Nat]) where
  Coord Unsafe '[_] = Int
  Coord Unsafe (_:_) = [Int]
  Coord ind '[n] = IndexOf ind n
  Coord ind (n:xs) = IndexOf ind n :# Coord ind xs

type family IndexOf (ind :: Ind) (n :: Nat)
type instance IndexOf Ordinal n = Finite n
type instance IndexOf Modular n = Mod n
type instance IndexOf Clamped n = Clamp n
type instance IndexOf Unsafe n = Int
type instance IndexOf Simple n = Int
type instance IndexOf Tag n = Tagged n
