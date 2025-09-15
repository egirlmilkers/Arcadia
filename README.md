<div align="center">
  
<img src="arcadia.png" alt="Arcadia Banner" width="500px">
  
**A sleek, cross-platform generative AI chat client built with Flutter, inspired by the Gemini UI.**

![GitHub Release](https://img.shields.io/github/v/release/egirlmilkers/Arcadia?display_name=release)
![GitHub Nightly](https://img.shields.io/github/v/release/egirlmilkers/Arcadia?include_prereleases&display_name=release&label=nightly)
![Flutter](https://img.shields.io/badge/Flutter%203.x-%2302569B.svg?&logo=Flutter&logoColor=white)

</div>

---

Arcadia provides a clean, customizable, and native cross-platform experience for interacting with your favorite generative AI models. It moves beyond the browser, giving you a dedicated and powerful interface on your desktop.

## ✨ Features

Arcadia is packed with features designed to enhance your AI chat experience.

* **🖥️ Cross-Platform:** Built with Flutter, Arcadia can run beautifully cross-platform (official support is planned).
* **🎨 Dynamic Theming:** Custom themes & support for using your system's color scheme for a personalized, native UI.
* **🖌️ Rich Markdown Rendering:** View responses in the clean, readable markdown format most APIs use.
* **💡 Syntax Highlighting:** Code blocks are syntax highlighted for dozens of languages, making technical responses easy to parse.
* **📎 File Attachments:** Attach images, videos, audio, and documents to your prompts (support depends on the model).
* **🤔 Thinking Summaries:** Get insight into the AI's generation process with the thinking view, showing a summary of the model's internal thoughts (support depends on the model).
* **✏️ Edit & Regenerate:** Easily edit your previous prompts or regenerate AI responses to refine your conversation.
* **⚙️ Highly Customizable:**
    * Choose from multiple built-in themes, enable dynamic system colors, or make your own!
    * Adjust contrast levels for better accessibility.
    * Add your own custom models via a simple JSON file (only supports models from APIs stated below).

## 🔌 Supported APIs & Models

Arcadia is built to be extensible. It currently has first-class support for Google's powerful AI ecosystems.

| API Provider | Authentication Method | Notes |
| :--- | :--- | :--- |
| <img src="https://www.gstatic.com/bricks/image/01dd37b1-cf14-4c80-8bfd-beb120ab4034.png" alt="Gemini Logo" width="15px"> **Google AI Studio** | API Key | The standard API for accessing Gemini models. |
| <img src="https://www.gstatic.com/bricks/image/77244d96-fa3d-4755-b61d-bddd4f775b2c.svg" alt="Vertex AI Studio Logo" width="15px"> **Google Vertex AI** | Service Account (JSON) | Google's enterprise-grade AI platform. Supports tuned models. |

By default, Arcadia comes pre-configured with:

* <img src="https://www.gstatic.com/bricks/image/01dd37b1-cf14-4c80-8bfd-beb120ab4034.png" alt="Gemini Logo" width="15px"> **Gemini 2.5 Flash**
* <img src="https://www.gstatic.com/bricks/image/01dd37b1-cf14-4c80-8bfd-beb120ab4034.png" alt="Gemini Logo" width="15px"> **Gemini 2.5 Pro**

## 🚀 Getting Started

To get started with Arcadia, you'll need to have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured on your system.

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/egirlmilkers/Arcadia.git
    cd Arcadia
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the application:**
    ```bash
    flutter run
    ```

## 🔑 API Configuration

To use Arcadia, you need to provide your own API keys. You can manage them inside the app by going to **Settings > Manage API Keys**.

### <img src="https://www.gstatic.com/bricks/image/01dd37b1-cf14-4c80-8bfd-beb120ab4034.png" alt="Gemini Logo" width="20px"> How to get a Gemini API Key

1.  Visit [Google AI Studio](https://aistudio.google.com/apikey).
2.  Sign in with your Google account.
3.  Click on **"+ Create API Key"** in the top right.
5.  Copy the generated API key.
6.  In Arcadia, go to **Settings > Manage API Keys**, click on the default `Gemini` key, and paste your key into the field.

### <img src="https://www.gstatic.com/bricks/image/77244d96-fa3d-4755-b61d-bddd4f775b2c.svg" alt="Vertex AI Studio Logo" width="20px"> How to set up Vertex AI (Advanced)

Using Vertex AI requires a Google Cloud project and a Service Account with the correct permissions.

1.  **Set up your Google Cloud Project:**
    * Go to the [Google Cloud Console](https://console.cloud.google.com/) and create a new project (or select an existing one).
    * Make sure billing is enabled for the project.
    * Go to the "APIs & Services" dashboard and click **"+ Enable APIs and services"**. Search for and enable the **"Vertex AI API"**.

2.  **Create a Service Account:**
    * In the Cloud Console, navigate to **IAM & Admin > Service Accounts**.
    * Click **"+ Create service account"**.
    * Give it a Service account name (e.g., `arcadia-vertex-user`).
    * Click **"Create and continue"**.
    * In the "Permissions" step, assign the role **`Vertex AI User`**.
    * Click **"Continue"**, then **"Done"** (ignore the "Principals with access" step).

3.  **Generate a JSON Key:**
    * Find your newly created service account in the list.
    * Click the three-dot menu under "Actions" and select **"Manage keys"**.
    * Click **"Add key" > "Create new key"**.
    * Select **JSON** as the key type and click **"Create"**. A `.json` file will be downloaded to your computer

4.  **Add the key to Arcadia:**
    * Open the downloaded `.json` file with a text editor and copy its **entire content**.
    * In Arcadia, go to **Settings > Manage API Keys** and click **"Add New"**.
    * Give it the name `Vertex` (currently no other name will work).
    * **Paste the entire JSON content** into the key field and save. You can now use models that use the Vertex AI API source (the `src` for the model must be `vertex`).

> [!CAUTION]
> KEEP THE JSON SAFE AND SECURE. DO NOT SHARE IT WITH ANYONE. ARCADIA WILL ONLY USE THIS LOCALLY.<br>
> YOU ARE FREE TO DELETE IT AFTER PASTING IT INTO ARCADIA BUT YOU MAY NOT BE ABLE TO OBTAIN IT AGAIN.

## 🛣️ Roadmap

Arcadia is under active development. Here are some of the features planned for future releases:

-   [ ] **Platform Expansion:** Web and Mobile versions.
-   [ ] **Broader Model Support:** Integrate OpenAI (ChatGPT), Gemma, DeepSeek, and other open models.
-   [ ] **Chat Management:** Pinning and searching chats as well as viewing archived chats.
-   [ ] **UX/UI Enhancements:**
    -   Drag-and-drop file attachments.
    -   Changeable syntax highlighting themes.
    -   Token count and cost estimation.
    -   Smoother, fully streamed responses.

## 🙌 Contributing

Contributions are welcome! If you have an idea for a new feature, find a bug, or want to improve the code, please feel free to open an issue!

## 📄 License

This project is licensed under the GNU GPLv3 License - see the [LICENSE.md](LICENSE.md) file for details.