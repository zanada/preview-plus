<p align="center">
  <img alt="Icon" width="220px" src="docs/icon.svg">
</p>

<h1 align="center">Preview Plus for Aseprite</h1>


<p align="center">An <a href="https://aseprite.org/">Aseprite</a> plugin that adds a preview window with extra functionality</p>

<p align="center">
<img src="docs/diagram.png" width="350" alt="Diagram">
</p>

I made this to experiment with plugins and make previews more useful for me. I hope other people can find use in it.

## Features
* **Display Area** - Choose what part of the canvas (selection or slice) to display in the preview. Useful framing and composition in a larger canvas
<p align="center">
<img src="docs/example1.gif"
width=500 
alt="Display area example"></img>
</p>

* **Tiling**- Tile in just the preview window without having to make a separate sprite
<p align="center">
<img src="docs/example2.gif"
width=500 
alt="Tiling example">
</p>

* **Isolate layer** - View just the selected layer OR group of layers
<p align="center">
<img src="docs/example3.gif"
width=500 
alt="Isolate Example">
</p>

* **Filters** - Set the type in the dropdown and toggle with the filter button
  * **Grayscale** - Preview just the grayscale values

  <p align="center">
  <img src="docs/example7.png"
  width=400 
  alt="Grayscale example">
  </p>

  * **Silhouette** - Show the silhouette of the selected layer or group of layers. You can also change the color it uses

  <p align="center">
  <img src="docs/example6.png"
  width=400 
  alt="Silhouette example">
  </p>

* **Follow Layer** - Choose to display a different layer or group than the editor. Useful for working while showing a clean view without guidelines or viewing overall silhouette

<p align="center">
<img src="docs/example5.png"
width=500 
alt="Playback example">
</p>

* **Animation Playback** - By default, the window behaves just like the Aseprite version
  * **Frame Slider** - Show a different frame that what is selected in editor
  * **Scope tag** - Set a scope tag for just the portion of animation you want to play
  * **Ignore sub tags** - Choose to follow sub tags just like the main editor
<p align="center">
<img src="docs/example4.gif"
width=500 
alt="Playback example">
</p>

* **Pin** - Pin to see the preview window for a sprite no matter what tab you are on


## Usage
With a sprite open in Aseprite, go to `View > Preview Plus > Preview Plus` to open a new preview window.

## Installation
1. Download preview-plus.aseprite-extension from [itch.io]() or from the [latest release](https://github.com/zanada/preview-plus/releases/latest)
2. Double-click the file to install. OR
1. In Aseprite, Go to `Edit > Preferences > Extensions` and click the `Add Extension` button.
2. Navigate to and select the downloaded file.
