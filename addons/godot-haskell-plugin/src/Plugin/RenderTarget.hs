{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE DataKinds #-}

module Plugin.RenderTarget where

import Control.Exception

import Data.Colour
import Data.Colour.SRGB.Linear

import Control.Monad
import Data.Coerce
import Unsafe.Coerce

import           Linear
import           Plugin.Imports

import           Godot.Extra.Register
import           Godot.Core.GodotGlobalConstants
import qualified Godot.Core.GodotRigidBody   as RigidBody
import           Godot.Gdnative.Internal.Api
import qualified Godot.Methods               as G
import qualified Godot.Gdnative.Internal.Api as Api

import Plugin.Types
import Data.Maybe
import Data.Either

import           Foreign
import           Foreign.Ptr
import           Foreign.Marshal.Alloc
import           Foreign.C.Types
import qualified Language.C.Inline as C

import           Control.Lens                hiding (Context)

import Data.Typeable

import qualified Data.Map.Strict as M

instance Eq GodotRenderTarget where
  (==) = (==) `on` _grtObj

instance GodotClass GodotRenderTarget where
  godotClassName = "RenderTarget"

instance ClassExport GodotRenderTarget where
  classInit obj =
    GodotRenderTarget obj
                  <$> atomically (newTVar (error "Failed to initialize GodotSimulaViewSprite."))
                  <*> atomically (newTVar (error "Failed to initialize GodotSimulaViewSprite."))
  classExtends = "RigidBody2D"
  classMethods =
    [
      GodotMethod NoRPC "_process" Plugin.RenderTarget._process
    , GodotMethod NoRPC "_draw" Plugin.RenderTarget._draw
    ]

instance HasBaseClass GodotRenderTarget where
  type BaseClass GodotRenderTarget = GodotRigidBody2D
  super (GodotRenderTarget obj _ _ ) = GodotRigidBody2D obj

newGodotRenderTarget :: GodotSimulaViewSprite -> IO (GodotRenderTarget)
newGodotRenderTarget gsvs = do
  -- putStrLn "newGodotSimulaViewSprite"
  putStrLn "A"

  grt <- "res://addons/godot-haskell-plugin/RenderTarget.gdns"
    & newNS' []
    >>= godot_nativescript_get_userdata
    >>= deRefStablePtr . castPtrToStablePtr :: IO GodotRenderTarget -- w/_grtObj populated + mempty TVars

  -- grt <- "res://addons/godot-haskell-plugin/RenderTarget.gdns"
  --   & newNS'' GodotRenderTarget "RenderTarget" []
  
  
  -- grt <- "res://addons/godot-haskell-plugin/RenderTarget.gdns"
  --         & newNS' []
  --         <&> GodotRenderTarget

  putStrLn "B"
  viewport <- initializeRenderTarget gsvs
  putStrLn "C"
  atomically $ writeTVar (_grtViewSprite grt) gsvs
  atomically $ writeTVar (_grtViewport grt) viewport
  -- G.set_process grt False

  return grt

getCoordinatesFromCenter :: GodotWlrSurface -> CInt -> CInt -> IO GodotVector2
getCoordinatesFromCenter wlrSurface sx sy = do
  -- putStrLn "getCoordinatesFromCenter"
  (bufferWidth', bufferHeight')    <- getBufferDimensions wlrSurface
  let (bufferWidth, bufferHeight)  = (fromIntegral bufferWidth', fromIntegral bufferHeight')
  let (fromTopLeftX, fromTopLeftY) = (fromIntegral sx, fromIntegral sy)
  let fromCenterX                  = -(bufferWidth/2) + fromTopLeftX
  let fromCenterY                  = -(-(bufferHeight/2) + fromTopLeftY)
  -- NOTE: In godotston fromCenterY is isn't negative, but since we set
  -- `G.render_target_v_flip viewport True` we can set this
  -- appropriately
  -- NOTE: We above assume that
  --    G.render_target_v_flip viewport True
  -- has been set.
  let v2 = (V2 fromCenterX fromCenterY) :: V2 Float
  gv2 <- toLowLevel v2 :: IO GodotVector2
  return gv2

useRenderTargetToDrawParentSurface :: GodotSimulaViewSprite -> IO ()
useRenderTargetToDrawParentSurface gsvs  = do
  putStrLn "useRenderTargetToDrawParentSurface"
  simulaView <- readTVarIO (gsvs ^. gsvsView)
  let eitherSurface = (simulaView ^. svWlrEitherSurface)
  wlrSurface <- getWlrSurface eitherSurface
  sprite3D <- readTVarIO (gsvs ^. gsvsSprite)
  grt <- readTVarIO (gsvs ^. gsvsRenderTarget)
  viewport <- readTVarIO (grt ^. grtViewport)
  viewportTexture <- G.get_texture viewport
  G.set_texture sprite3D (safeCast viewportTexture)
  G.send_frame_done wlrSurface
  return ()

_process :: GFunc GodotRenderTarget
_process self args = do
  putStrLn "_process"
  G.update self
  retnil

_draw :: GFunc GodotRenderTarget
_draw self args = do
  putStrLn "_draw"
  gsvs <- readTVarIO (self ^. grtViewSprite)
  sprite3D <- readTVarIO (gsvs ^. gsvsSprite)
  simulaView <- readTVarIO (gsvs ^. gsvsView)
  let eitherSurface = (simulaView ^. svWlrEitherSurface)
  wlrSurface <- getWlrSurface eitherSurface
  parentWlrTexture <- G.get_texture wlrSurface

  -- Draw texture on Viewport; get its texture; set it to Sprite3D's texture; call G.send_frame_done
  let isNull = ((unsafeCoerce parentWlrTexture) == nullPtr)
  case isNull of
        True -> putStrLn "Texture is null!"
        False -> do -- renderTarget <- initializeRenderTarget gsvs     -- Dumb, but we reset the renderTarget every frame to make sure the dimensions aren't (0,0)
                    -- atomically $ writeTVar (_gsvsViewport gsvs) renderTarget -- "
                    
                    -- Get state
                    -- let zero = (V2 0 0) :: V2 Float
                    -- gv2 <- toLowLevel zero :: IO GodotVector2
                    -- return zero
                    renderPosition <- getCoordinatesFromCenter wlrSurface 0 0 -- Surface coordinates are relative to the size of the GodotWlrXdgSurface; We draw at the top left.

                    textureToDraw <- G.get_texture wlrSurface :: IO GodotTexture
                    grt <- readTVarIO (gsvs ^. gsvsRenderTarget)
                    viewport <- readTVarIO (grt ^. grtViewport)

                      -- Send draw command
                    godotColor <- (toLowLevel $ (rgb 1.0 1.0 1.0) `withOpacity` 1) :: IO GodotColor
                    -- let nullTexture = Data.Maybe.fromJust ((fromVariant VariantNil) :: Maybe GodotTexture) :: GodotTexture
                    G.draw_texture ((unsafeCoerce viewport) :: GodotCanvasItem) textureToDraw renderPosition godotColor (coerce nullPtr) -- nullTexture
  retnil

initializeRenderTarget :: GodotSimulaViewSprite -> IO (GodotViewport)
initializeRenderTarget gsvs = do
  simulaView <- readTVarIO (gsvs ^. gsvsView)
  let eitherSurface = (simulaView ^. svWlrEitherSurface)
  wlrSurface <- getWlrSurface eitherSurface

  -- putStrLn "initializeRenderTarget"
  -- "When we are drawing to a Viewport that is not the Root, we call it a
  --  render target." -- Godot documentation"
  renderTarget <- unsafeInstance GodotViewport "Viewport"
  -- No need to add the Viewport to the SceneGraph since we plan to use it as a render target
    -- G.set_name viewport =<< toLowLevel "Viewport"
    -- G.add_child gsvs ((safeCast viewport) :: GodotObject) True

  G.set_disable_input renderTarget True -- Turns off input handling

  G.set_usage renderTarget 0 -- USAGE_2D = 0
  -- G.set_hdr renderTarget False -- Might be useful to disable HDR rendering for performance in the future (requires upgrading gdwlroots to GLES3)

  -- "Every frame, the Viewport’s texture is cleared away with the default clear
  -- color (or a transparent color if Transparent BG is set to true). This can
  -- be changed by setting Clear Mode to Never or Next Frame. As the name
  -- implies, Never means the texture will never be cleared, while next frame
  -- will clear the texture on the next frame and then set itself to Never."
  --
  --   CLEAR_MODE_ALWAYS = 0
  --   CLEAR_MODE_NEVER = 1
  -- 
  G.set_clear_mode renderTarget 0

  -- "By default, re-rendering of the Viewport happens when the Viewport’s
  -- ViewportTexture has been drawn in a frame. If visible, it will be rendered;
  -- otherwise, it will not. This behavior can be changed to manual rendering
  -- (once), or always render, no matter if visible or not. This flexibility
  -- allows users to render an image once and then use the texture without
  -- incurring the cost of rendering every frame."
  --
  -- UPDATE_DISABLED = 0 — Do not update the render target.
  -- UPDATE_ONCE = 1 — Update the render target once, then switch to UPDATE_DISABLED.
  -- UPDATE_WHEN_VISIBLE = 2 — Update the render target only when it is visible. This is the default value.
  -- UPDATE_ALWAYS = 3 — Always update the render target. 
  G.set_update_mode renderTarget 3

  -- "Note that due to the way OpenGL works, the resulting ViewportTexture is flipped vertically. You can use Image.flip_y on the result of Texture.get_data to flip it back[or you can also use set_vflip]:" -- Godot documentation
  G.set_vflip renderTarget True -- In tutorials this is set as True, but no reference to it in Godotston; will set to True for now

  -- We could alternatively set the size of the renderTarget via set_size_override [and set_size_override_stretch]
  dimensions@(width, height) <- getBufferDimensions wlrSurface
  pixelDimensionsOfWlrSurface <- toGodotVector2 dimensions

  -- Here I'm attempting to set the size of the viewport to the pixel dimensions
  -- of our wlrXdgSurface argument:
  G.set_size renderTarget pixelDimensionsOfWlrSurface

  -- There is, however, an additional way to do this and I'm not sure which one
  -- is better/more idiomatic:
    -- G.set_size_override renderTarget True vector2
    -- G.set_size_override_stretch renderTarget True

  return renderTarget
  where
        -- | Used to supply GodotVector2 to
        -- |   G.set_size :: GodotViewport -> GodotVector2 -> IO ()
        toGodotVector2 :: (Int, Int) -> IO (GodotVector2)
        toGodotVector2 (width, height) = do
          let v2 = (V2 (fromIntegral width) (fromIntegral height))
          gv2 <- toLowLevel v2 :: IO (GodotVector2)
          return gv2

getBufferDimensions :: GodotWlrSurface -> IO (Int, Int)
getBufferDimensions wlrSurface = do
  wlrSurfaceState <- G.get_current_state wlrSurface -- isNull: False
  bufferWidth <- G.get_buffer_width wlrSurfaceState
  bufferHeight <- G.get_buffer_height wlrSurfaceState
  width <- G.get_width wlrSurfaceState
  height <-G.get_height wlrSurfaceState
  -- putStrLn $ "getBufferDimensions (buffer width/height): (" ++ (show bufferWidth) ++ "," ++ (show bufferHeight) ++ ")"
  -- putStrLn $ "getBufferDimensions (width/height): (" ++ (show width) ++ "," ++ (show height) ++ ")"
  return (bufferWidth, bufferHeight) -- G.set_size expects "the width and height of viewport" according to Godot documentation
