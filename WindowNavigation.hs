{-# OPTIONS -fglasgow-exts #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  XMonadContrib.WorkspaceDir
-- Copyright   :  (c) 2007  David Roundy <droundy@darcs.net>
-- License     :  BSD3-style (see LICENSE)
-- 
-- Maintainer  :  David Roundy <droundy@darcs.net>
-- Stability   :  unstable
-- Portability :  unportable
--
-- WindowNavigation is an extension to allow easy navigation of a workspace.
--
-----------------------------------------------------------------------------

module XMonadContrib.WindowNavigation ( 
                                   -- * Usage
                                   -- $usage
                                   windowNavigation,
                                   Navigate(..), Direction(..)
                                  ) where

import Graphics.X11.Xlib ( Rectangle(..), Window, setWindowBorder )
import Control.Monad.Reader ( asks )
import Data.List ( nub, sortBy, (\\) )
import XMonad
import qualified StackSet as W
import Operations ( focus, initColor )
import XMonadContrib.LayoutModifier
import XMonadContrib.Invisible

-- $usage
-- You can use this module with the following in your Config.hs file:
--
-- > import XMonadContrib.WindowNavigation
-- >
-- > defaultLayout = SomeLayout $ windowNavigation $ LayoutSelection ...
--
-- In keybindings:
--
-- >    , ((modMask, xK_Right), sendMessage $ Go R)
-- >    , ((modMask, xK_Left), sendMessage $ Go L)
-- >    , ((modMask, xK_Up), sendMessage $ Go U)
-- >    , ((modMask, xK_Down), sendMessage $ Go D)

-- %import XMonadContrib.WindowNavigation
-- %keybind , ((modMask, xK_Right), sendMessage $ Go R)
-- %keybind , ((modMask, xK_Left), sendMessage $ Go L)
-- %keybind , ((modMask, xK_Up), sendMessage $ Go U)
-- %keybind , ((modMask, xK_Down), sendMessage $ Go D)
-- %layout -- include 'windowNavigation' in defaultLayout definition above.
-- %layout -- just before the list, like the following (don't uncomment next line):
-- %layout -- defaultLayout = SomeLayout $ windowNavigation $ ...


data Navigate = Go Direction deriving ( Read, Show, Typeable )
data Direction = U | D | R | L deriving ( Read, Show, Eq )
instance Message Navigate

data NavigationState a = NS Point [(a,Rectangle)]

data WindowNavigation a = WindowNavigation (Invisible Maybe (NavigationState a)) deriving ( Read, Show )

windowNavigation = ModifiedLayout (WindowNavigation (I Nothing))

instance LayoutModifier WindowNavigation Window where
    redoLayout (WindowNavigation state) rscr s wrs =
        do dpy <- asks display
           --navigableColor <- io $ (Just `fmap` initColor dpy "#0000FF") `catch` \_ -> return Nothing
           --otherColor <- io $ (Just `fmap` initColor dpy "#000000") `catch` \_ -> return Nothing
           let sc mc win = case mc of
                           Just c -> io $ setWindowBorder dpy win c
                           Nothing -> return ()
               w = W.focus s
               r = case filter ((==w).fst) wrs of ((_,x):_) -> x
                                                  [] -> rscr
               pt = case state of I (Just (NS ptold _)) | ptold `inrect` r -> ptold
                                  _ -> center r
               wrs' = filter ((/=w) . fst) wrs
               wnavigable = nub $ map fst $ concatMap (\d -> filter (inr d pt . snd) wrs') [U,D,R,L]
               wothers = map fst wrs' \\ wnavigable
           --mapM_ (sc navigableColor) wnavigable
           --mapM_ (sc otherColor) wothers
           return (wrs, Just $ WindowNavigation $ I $ Just $ NS pt wrs')
    modifyModify (WindowNavigation (I (Just (NS pt wrs)))) m
        | Just (Go d) <- fromMessage m = case sortby d $ filter (inr d pt . snd) wrs of
                                           [] -> return Nothing
                                           ((w,r):_) -> do focus w
                                                           return $ Just $ WindowNavigation $ I $ Just $ NS (centerd d pt r) []
    modifyModify _ _ = return Nothing

center (Rectangle x y w h) = P (fromIntegral x + fromIntegral w/2)  (fromIntegral y + fromIntegral h/2)
centerd d (P xx yy) (Rectangle x y w h) | d == U || d == D = P xx (fromIntegral y + fromIntegral h/2)
                                        | otherwise = P (fromIntegral x + fromIntegral w/2) yy
inr D  (P x y) (Rectangle l yr w h) = x >= fromIntegral l && x <= fromIntegral l + fromIntegral w &&
                                      y <  fromIntegral yr + fromIntegral h
inr U  (P x y) (Rectangle l yr w _) = x >= fromIntegral l && x <= fromIntegral l + fromIntegral w &&
                                      y >  fromIntegral yr
inr R  (P a x) (Rectangle b l _ w)  = x >= fromIntegral l && x <= fromIntegral l + fromIntegral w &&
                                      a <  fromIntegral b
inr L  (P a x) (Rectangle b l c w)  = x >= fromIntegral l && x <= fromIntegral l + fromIntegral w &&
                                      a >  fromIntegral b + fromIntegral c
inrect (P x y) (Rectangle a b w h)  = x >  fromIntegral a && x <  fromIntegral a + fromIntegral w &&
                                      y >  fromIntegral b && y <  fromIntegral b + fromIntegral h

sortby U = sortBy (\(_,Rectangle _ y _ _) (_,Rectangle _ y' _ _) -> compare y' y)
sortby D = sortBy (\(_,Rectangle _ y _ _) (_,Rectangle _ y' _ _) -> compare y y')
sortby R = sortBy (\(_,Rectangle x _ _ _) (_,Rectangle x' _ _ _) -> compare x x')
sortby L = sortBy (\(_,Rectangle x _ _ _) (_,Rectangle x' _ _ _) -> compare x' x)

data Point = P Double Double
