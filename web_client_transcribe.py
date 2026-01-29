import gradio as gr
import requests
import os

# --- LOGIQUE MÉTIER (INCHANGÉE) ---
WHISPER_API_URL = "http://localhost:8025/inference"

def transcribe_audio(audio_filepath, language, temperature, translate):
    if audio_filepath is None:
        return "⚠️ Aucun audio détecté."

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

            print(f"📤 Envoi vers {WHISPER_API_URL} | Langue: {language} | Temp: {temperature}")
            
            response = requests.post(WHISPER_API_URL, files=files, data=data)
            
            if response.status_code == 200:
                result = response.json()
                text = result.get("text", "")
                return text.strip()
            else:
                return f"❌ Erreur Serveur ({response.status_code}): {response.text}"

    except Exception as e:
        return f"❌ Erreur Python : {str(e)}"

# --- INTERFACE GRADIO AMÉLIORÉE ---
# Utilisation d'un thème "Soft" pour un rendu plus moderne et propre
with gr.Blocks(title="Whisper Studio DGX", theme=gr.themes.Soft(primary_hue="blue", neutral_hue="slate")) as demo:
    
    # En-tête épuré
    gr.Markdown(
        """
        # 🎙️ Whisper Studio (DGX)
        *Enregistrez votre voix ou glissez un fichier audio. La transcription démarre automatiquement.*
        """
    )
    
    with gr.Row(equal_height=True):
        
        # --- COLONNE GAUCHE : INPUT & RÉGLAGES (1/3 de l'écran) ---
        with gr.Column(scale=1, variant="panel"):
            gr.Markdown("### 1. Source Audio")
            
            # Composant Audio principal
            audio_input = gr.Audio(
                sources=["microphone", "upload"],
                type="filepath", 
                label="",
                show_label=False, # Plus propre sans label redondant
                render=True
            )
            
            # Séparation visuelle
            gr.Markdown("---")
            
            # Les réglages sont repliables pour garder l'interface propre
            with gr.Accordion("⚙️ Paramètres de Transcription", open=True):
                with gr.Group():
                    lang_dropdown = gr.Dropdown(
                        choices=["auto", "fr", "en", "de", "es", "it", "tr"], 
                        value="fr", 
                        label="Langue parlée"
                    )
                    
                    with gr.Row():
                        temp_slider = gr.Slider(
                            minimum=0.0, 
                            maximum=1.0, 
                            value=0.0, 
                            step=0.1, 
                            label="Créativité (Temp)"
                        )
                        translate_check = gr.Checkbox(
                            label="Traduction EN",
                            value=False,
                            info="Sortie en anglais"
                        )
            
            # Bouton utilitaire pour nettoyer
            clear_btn = gr.Button("🗑️ Nouvelle session", variant="secondary", size="sm")

        # --- COLONNE DROITE : RÉSULTAT (2/3 de l'écran) ---
        with gr.Column(scale=2):
            gr.Markdown("### 2. Résultat")
            text_output = gr.Textbox(
                label="Transcription",
                show_label=True,
                buttons=["copy"],
                placeholder="Le texte transcrit apparaîtra ici...",
                lines=20, # Plus grand pour le confort de lecture
                interactive=True, # Permet de sélectionner/copier le texte
                elem_id="output_box"
            )

    # --- LOGIQUE ÉVÉNEMENTIELLE (AUTO-START) ---
    
    # 1. Fin d'enregistrement -> Transcription
    audio_input.stop_recording(
        fn=transcribe_audio,
        inputs=[audio_input, lang_dropdown, temp_slider, translate_check],
        outputs=text_output
    )

    # 2. Upload de fichier -> Transcription
    audio_input.upload(
        fn=transcribe_audio,
        inputs=[audio_input, lang_dropdown, temp_slider, translate_check],
        outputs=text_output
    )
    
    # 3. Bouton Reset
    def reset_interface():
        return None, ""
        
    clear_btn.click(fn=reset_interface, outputs=[audio_input, text_output])

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=7860)