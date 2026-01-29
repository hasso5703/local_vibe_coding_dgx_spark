import gradio as gr
import requests
import os

# --- BUSINESS LOGIC (UNCHANGED) ---
WHISPER_API_URL = "http://localhost:8025/inference"

def transcribe_audio(audio_filepath, language, temperature, translate):
    if audio_filepath is None:
        return "⚠️ No audio detected."

    try:
        with open(audio_filepath, "rb") as f:
            files = {
                "file": ("audio.wav", f, "audio/wav")
            }

            data = {
                "temperature": str(temperature),
                "response_format": "json",
            }

            if language != "auto":
                data["language"] = language

            if translate:
                data["translate"] = "true"

            print(f"📤 Sending to {WHISPER_API_URL} | Language: {language} | Temp: {temperature}")

            response = requests.post(WHISPER_API_URL, files=files, data=data)

            if response.status_code == 200:
                result = response.json()
                text = result.get("text", "")
                return text.strip()
            else:
                return f"❌ Server Error ({response.status_code}): {response.text}"

    except Exception as e:
        return f"❌ Python Error: {str(e)}"

# --- GRADIO INTERFACE ENHANCED ---
# Using "Soft" theme for a cleaner, more modern look
with gr.Blocks(title="Whisper Studio", theme=gr.themes.Soft(primary_hue="blue", neutral_hue="slate")) as demo:

    # Clean header
    gr.Markdown(
        """
        # 🎙️ Whisper Studio
        *Record your voice or drag and drop an audio file. Transcription starts automatically.*
        """
    )

    with gr.Row(equal_height=True):

        # --- LEFT COLUMN: INPUT & SETTINGS (1/3 of screen) ---
        with gr.Column(scale=1, variant="panel"):
            gr.Markdown("### 1. Audio Source")

            # Main audio component
            audio_input = gr.Audio(
                sources=["microphone", "upload"],
                type="filepath",
                label="",
                show_label=False, # Cleaner without redundant label
                render=True
            )

            # Visual separator
            gr.Markdown("---")

            # Settings are collapsible to keep interface clean
            with gr.Accordion("⚙️ Transcription Settings", open=True):
                with gr.Group():
                    lang_dropdown = gr.Dropdown(
                        choices=["auto", "fr", "en", "de", "es", "it", "tr"],
                        value="fr",
                        label="Spoken Language"
                    )

                    with gr.Row():
                        temp_slider = gr.Slider(
                            minimum=0.0,
                            maximum=1.0,
                            value=0.0,
                            step=0.1,
                            label="Creativity (Temp)"
                        )
                        translate_check = gr.Checkbox(
                            label="Translate to English",
                            value=False,
                            info="Output in English"
                        )

            # Utility button to clear
            clear_btn = gr.Button("🗑️ New Session", variant="secondary", size="sm")

        # --- RIGHT COLUMN: RESULTS (2/3 of screen) ---
        with gr.Column(scale=2):
            gr.Markdown("### 2. Results")
            text_output = gr.Textbox(
                label="Transcription",
                show_label=True,
                buttons=["copy"],
                placeholder="The transcribed text will appear here...",
                lines=20, # Larger for comfortable reading
                interactive=True, # Allows text selection/copying
                elem_id="output_box"
            )

    # --- EVENT LOGIC (AUTO-START) ---

    # 1. Recording ends -> Transcribe
    audio_input.stop_recording(
        fn=transcribe_audio,
        inputs=[audio_input, lang_dropdown, temp_slider, translate_check],
        outputs=text_output
    )

    # 2. File upload -> Transcribe
    audio_input.upload(
        fn=transcribe_audio,
        inputs=[audio_input, lang_dropdown, temp_slider, translate_check],
        outputs=text_output
    )

    # 3. Reset button
    def reset_interface():
        return None, ""

    clear_btn.click(fn=reset_interface, outputs=[audio_input, text_output])

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=7860)
