# SatViewAR 

## Abstract
This iPhone application leverages AR (Augmented Reality) technology to visually map satellites that can be received at the user's current location in three-dimensional space. This intuitive method aids in identifying Non-Line-Of-Sight (NLOS) satellites, a common issue in urban canyons, forested, and mountainous areas where GPS errors can range from a few to tens of meters. Additionally, AI is incorporated to enhance the determination of the NLOS state of satellites. The app presents a fast, convenient, and low-cost solution for NLOS detection, improving accuracy in various fields such as autonomous driving, aviation, and military operations.

<p align="center">
<img src="https://github.com/SeanBaek111/SatViewAR/assets/33170173/f3725f71-8993-425c-a8aa-cfd17976e8ec" width="256">
<img src="https://github.com/SeanBaek111/SatViewAR/assets/33170173/aa57a23c-5e3f-49bd-b812-e88adddcf69f" width="256">  
</p>

## Demo Video
[Watch the video](https://www.youtube.com/watch?v=IyCVtOgI_Wc)


## Features

- **AR Visualization**: Use your iPhone to see and identify satellites in three-dimensional space around you.
- **AI-Powered Detection**: Our advanced AI algorithms determine the NLOS status of each satellite.
- **Easy to Use**: A user-friendly interface that does not require technical expertise to operate.
- **Portable**: As an iPhone app, it provides a mobile solution to be used in various outdoor environments.

## Installation

1. Clone the repository to your local machine:
2. Open the project in Xcode.
3. Connect your iPhone to your computer and select it as the build destination in Xcode.
4. Press the 'Run' button to build and run the application on your device.

Make sure you have the latest version of Xcode installed and a valid Apple Developer account to run the app on a device.

## Usage

After launching the app, point your iPhone to the sky. To update the display with satellites that are currently above the horizon and receivable from your location, press the 'Refresh' button. These satellites will appear as AR objects. For analysis, use the 'Measure' button. This action triggers the app to perform semantic segmentation on the satellites visible on your screen, determining their NLOS (Non-Line of Sight) status using the integrated AI model. Once you have measured all the satellites, the app will present statistics and display the satellites distinctly, color-coded based on their NLOS status.

## Contributing

Contributions to the NLOS Satellite Detector app are welcome!

Please follow these steps to contribute:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Make your changes and commit them (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## License

Licensed under the Apache License, Version 2.0 (the "[License](https://github.com/SeanBaek111/SatViewAR/blob/main/LICENSE)") 

## Contact

For any queries or feedback, please open an issue on the GitHub repository issue tracker.

---
I hope this app empowers you to navigate with greater confidence and precision!
