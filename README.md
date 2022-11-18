# 20x20

This is repository for an art-technology project called "20x20". The project is in one way a tribute to the era of limited resources, when each pixel mattered a lot and could change the visual content. On the other hand the project is an exploration of using a minimalist way to convey information in public spaces.

The basis of the project is an array of LED diodes arranged in a 20x20 matrix. The display is located in the lobby of the Faculty of Computer and Information Science at University of Ljubljana.

## Contributing

Contributions are welcome, you can provide new visualizations (tiles) or enhance the supporting system. Use pull requests to do so.

## Repository structure

Repository consists of several parts

 * Lua code that is run on a Wemos D1 micro controller which controls an addressable LED strip of 400 diodes. This are the `core` and `tiles` folders.
 * Python `tools` that are run on a computer and provide a simple emulator, a converter of images to sprites and a tool that uploads files to the micro controller. Install requirements from the `requirements.txt` file to use them.
 * Some graphics `resources`.

