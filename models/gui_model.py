import os
import tkinter as tk
from tkinter import ttk, messagebox
from ttkthemes import ThemedTk
import cv2
import numpy as np
import librosa
import sounddevice as sd
import soundfile as sf
import tensorflow as tf
import pickle
import torch
from transformers import DistilBertTokenizerFast, DistilBertForSequenceClassification
from PIL import Image, ImageTk
import threading
import time
import random
import speech_recognition as sr

# --- Paths and Constants ---
BASE_DIR = os.path.dirname(__file__)
FACE_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'emotion_recognition_model_100.h5')
AUDIO_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'Speech Emotion Recognition Minor Project', 'LSTM Model', 'speech_emotion_recognition_model_lstm.h5')
SCALER_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'Speech Emotion Recognition Minor Project', 'LSTM Model', 'scalerLSTM.pkl')
TEXT_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'emotion-distilbert-model')

FACE_IMG_SIZE = (48, 48)
AUDIO_DURATION = 4
AUDIO_SR = 16000

FACE_LABELS = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']
AUDIO_LABELS = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']
TEXT_LABELS = ['anger', 'joy', 'sadness', 'fear', 'love', 'surprise']

EMOTION_ICONS = {
    'angry': '😡', 'disgust': '🤢', 'fear': '😨', 'happy': '😄', 'neutral': '😐',
    'sad': '😢', 'surprise': '😲', 'joy': '😄', 'sadness': '😢', 'anger': '😡', 'love': '❤️', 'default': '❓'
}

AUDIO_QUESTIONS = [
    "How are you feeling today?",
    "What is one thing that's on your mind?",
    "Describe your mood in a few words.",
    "How has your week been so far?",
    "Is there something that's been bothering you?"
]

TEXT_QUESTIONS = [
    "Write a few words about how you feel right now.",
    "Describe your current mood.",
    "Is there anything you'd like to express today?",
    "Share something that's on your mind.",
    "How have you been emotionally?"
]

# --- Model Loading with Error Handling ---
def safe_load_model(load_func, *args, **kwargs):
    try:
        return load_func(*args, **kwargs)
    except Exception as e:
        print(f"Error loading model: {e}")
        import traceback
        traceback.print_exc()
        return None

face_model = safe_load_model(tf.keras.models.load_model, FACE_MODEL_PATH)

try:
    with open(SCALER_PATH, 'rb') as f:
        audio_scaler = pickle.load(f)
    audio_model = tf.keras.models.load_model(AUDIO_MODEL_PATH)
except Exception as e:
    print(f"Error loading audio model/scaler: {e}")
    import traceback
    traceback.print_exc()
    audio_model = None
    audio_scaler = None

try:
    text_tokenizer = DistilBertTokenizerFast.from_pretrained(TEXT_MODEL_PATH)
    text_model = DistilBertForSequenceClassification.from_pretrained(TEXT_MODEL_PATH)
    text_model.eval()
except Exception as e:
    print(f"Error loading text model/tokenizer: {e}")
    import traceback
    traceback.print_exc()
    text_tokenizer = None
    text_model = None

# --- Utility Functions ---
def detect_face(frame):
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 4)
    if len(faces) > 0:
        x, y, w, h = max(faces, key=lambda rect: rect[2]*rect[3])
        return gray[y:y+h, x:x+w], (x, y, w, h)
    return None, None

def predict_face_emotion(img_array):
    if face_model is None:
        return "Model not loaded", None
    try:
        img = img_array.astype('float32') / 255.0
        img = np.expand_dims(img, axis=(0, -1))
        preds = face_model.predict(img, verbose=0)
        label = FACE_LABELS[np.argmax(preds)]
        return label, preds[0]
    except Exception as e:
        print(f"Error predicting face emotion: {e}")
        import traceback
        traceback.print_exc()
        return "Error", None

def extract_audio_features(y, sr):
    try:
        zcr = np.mean(librosa.feature.zero_crossing_rate(y=y).T, axis=0)
        stft = np.abs(librosa.stft(y))
        chroma_stft = np.mean(librosa.feature.chroma_stft(S=stft, sr=sr).T, axis=0)
        mfcc = np.mean(librosa.feature.mfcc(y=y, sr=sr).T, axis=0)
        rms = np.mean(librosa.feature.rms(y=y).T, axis=0)
        mel = np.mean(librosa.feature.melspectrogram(y=y, sr=sr).T, axis=0)
        return np.hstack((zcr, chroma_stft, mfcc, rms, mel))
    except Exception as e:
        print(f"Error extracting audio features: {e}")
        import traceback
        traceback.print_exc()
        raise

def predict_audio_emotion(file_path):
    if audio_model is None or audio_scaler is None:
        return "Model not loaded", None
    try:
        y, sr = librosa.load(file_path, sr=AUDIO_SR)
        features = extract_audio_features(y, sr)
        features_scaled = audio_scaler.transform(features.reshape(1, -1))
        features_reshaped = np.expand_dims(features_scaled, axis=2)
        preds = audio_model.predict(features_reshaped, verbose=0)
        label = AUDIO_LABELS[np.argmax(preds)]
        return label, preds[0]
    except Exception as e:
        print(f"Error in audio prediction: {e}")
        import traceback
        traceback.print_exc()
        return "Error", None

def predict_text_emotion(text):
    if text_model is None or text_tokenizer is None:
        return "Model not loaded", None
    try:
        inputs = text_tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=128)
        with torch.no_grad():
            outputs = text_model(**inputs)
            logits = outputs.logits
            pred = torch.argmax(logits, dim=1).item()
            return TEXT_LABELS[pred], logits[0].softmax(dim=0).numpy()
    except Exception as e:
        print(f"Error predicting text emotion: {e}")
        import traceback
        traceback.print_exc()
        return "Error", None

def transcribe_audio(file_path):
    try:
        recognizer = sr.Recognizer()
        with sr.AudioFile(file_path) as source:
            audio_data = recognizer.record(source)
        return recognizer.recognize_google(audio_data)
    except Exception as e:
        print(f"Speech recognition error: {e}")
        import traceback
        traceback.print_exc()
        return ""

# --- GUI Application ---
class EmotionApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Multimodal Emotion Dashboard")
        self.root.geometry("1200x700")
        self.root.minsize(1000, 600)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)
        style = ttk.Style(self.root)
        style.theme_use('arc')

        # Tkinter Variables
        self.face_pred_icon = tk.StringVar(value='❓')
        self.face_pred_label = tk.StringVar(value='Detecting...')
        self.audio_pred_icon = tk.StringVar(value='❓')
        self.audio_pred_label = tk.StringVar(value='Not predicted')
        self.audio_status = tk.StringVar(value="Ready")
        self.text_pred_icon = tk.StringVar(value='❓')
        self.text_pred_label = tk.StringVar(value='Not predicted')
        self.audio_question = tk.StringVar(value=random.choice(AUDIO_QUESTIONS))
        self.text_question = tk.StringVar(value=random.choice(TEXT_QUESTIONS))
        self.audio_transcript = tk.StringVar(value="")
        self.audio_play_btn_state = tk.StringVar(value="disabled")
        self.record_gain = tk.DoubleVar(value=1.0)
        self.playback_gain = tk.DoubleVar(value=1.0)

        # Layout
        self.main_frame = ttk.Frame(self.root, padding=10)
        self.main_frame.pack(fill='both', expand=True)

        # Left: Camera & Face
        self.left_frame = ttk.Frame(self.main_frame)
        self.left_frame.pack(side="left", fill="both", expand=True, padx=(0, 10))

        # Right: Audio (top) and Text (bottom)
        self.right_frame = ttk.Frame(self.main_frame)
        self.right_frame.pack(side="right", fill="both", expand=True)
        self.right_top = ttk.Frame(self.right_frame)
        self.right_top.pack(side="top", fill="both", expand=True, pady=(0, 5))
        self.right_bottom = ttk.Frame(self.right_frame)
        self.right_bottom.pack(side="bottom", fill="both", expand=True, pady=(5, 0))

        self.build_face_panel(self.left_frame)
        self.build_audio_panel(self.right_top)
        self.build_text_panel(self.right_bottom)

        # For camera
        self.cap = cv2.VideoCapture(0)
        self.face_update_interval = 100  # ms
        self.face_last_pred_time = 0
        self.face_pred_probs = None
        self.update_camera()

    def on_close(self):
        self.cap.release()
        self.root.destroy()

    # --- Face Panel ---
    def build_face_panel(self, parent):
        title = ttk.Label(parent, text="Camera & Face Emotion", font=("Arial", 16, "bold"))
        title.pack(anchor="center", pady=(0, 10))
        self.face_canvas = tk.Label(parent, borderwidth=2, relief="groove")
        self.face_canvas.pack(anchor="center", padx=10, pady=10, expand=True)
        info_frame = ttk.Frame(parent)
        info_frame.pack(anchor="center", pady=(10, 0))
        ttk.Label(info_frame, text="Predicted Emotion:", font=("Arial", 12)).pack(anchor="w")
        self.face_emoji_label = ttk.Label(info_frame, textvariable=self.face_pred_icon, font=("Arial", 40))
        self.face_emoji_label.pack(anchor="w")
        self.face_label_label = ttk.Label(info_frame, textvariable=self.face_pred_label, font=("Arial", 16, "bold"))
        self.face_label_label.pack(anchor="w", pady=(0, 10))
        self.face_probs_frame = ttk.Frame(info_frame)
        self.face_probs_frame.pack(anchor="w", fill="x", pady=(10, 0))
        self.face_prob_bars = {}
        for i, label in enumerate(FACE_LABELS):
            bar = ttk.Progressbar(self.face_probs_frame, orient="horizontal", length=120, mode="determinate", maximum=1.0)
            bar.grid(row=i, column=1, sticky="ew", padx=5, pady=2)
            ttk.Label(self.face_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label.title()}").grid(row=i, column=0, sticky="w")
            self.face_prob_bars[label] = bar

    def update_camera(self):
        ret, frame = self.cap.read()
        if ret:
            display_frame = frame.copy()
            face_img, face_rect = detect_face(frame)
            now = time.time()
            if face_img is not None and now - self.face_last_pred_time > 0.8:
                resized = cv2.resize(face_img, FACE_IMG_SIZE)
                threading.Thread(target=self.face_predict_thread, args=(resized,)).start()
                self.face_last_pred_time = now
            if face_rect:
                x, y, w, h = face_rect
                cv2.rectangle(display_frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
            rgb = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(rgb)
            img = img.resize((400, 300))
            self.face_photo = ImageTk.PhotoImage(image=img)
            self.face_canvas.config(image=self.face_photo)
        self.root.after(self.face_update_interval, self.update_camera)

    def face_predict_thread(self, face_img):
        label, probs = predict_face_emotion(face_img)
        icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
        self.face_pred_label.set(label.title())
        self.face_pred_icon.set(icon)
        self.face_pred_probs = probs
        def update_bars():
            if probs is not None:
                for i, l in enumerate(FACE_LABELS):
                    self.face_prob_bars[l]['value'] = probs[i]
        self.root.after(0, update_bars)

    # --- Audio Panel ---
    def build_audio_panel(self, frame):
        ttk.Label(frame, text="Audio Emotion", font=("Arial", 15, "bold")).pack(anchor="w", padx=10, pady=(0, 5))
        ttk.Label(frame, textvariable=self.audio_question, font=("Arial", 12, "italic"), foreground="#0077b6").pack(anchor="w", padx=10, pady=(0, 5))
        self.audio_record_btn = ttk.Button(frame, text="🎙️ Record Audio", command=self.toggle_audio_record)
        self.audio_record_btn.pack(anchor="w", padx=10, pady=5)
        self.audio_play_btn = ttk.Button(frame, text="▶️ Play Recording", command=self.play_audio, state="disabled")
        self.audio_play_btn.pack(anchor="w", padx=10, pady=(0, 5))
        ttk.Label(frame, text="Mic Gain (Recording)").pack(anchor="w", padx=10)
        self.record_slider = ttk.Scale(frame, from_=0.5, to=3.0, orient="horizontal", variable=self.record_gain, length=150)
        self.record_slider.pack(anchor="w", padx=10, pady=(0, 5))
        ttk.Label(frame, text="Playback Volume").pack(anchor="w", padx=10)
        self.playback_slider = ttk.Scale(frame, from_=0.0, to=2.0, orient="horizontal", variable=self.playback_gain, length=150)
        self.playback_slider.pack(anchor="w", padx=10, pady=(0, 5))
        self.audio_status_label = ttk.Label(frame, textvariable=self.audio_status, font=("Arial", 10))
        self.audio_status_label.pack(anchor="w", padx=10, pady=(0, 5))
        ttk.Label(frame, text="Predicted Emotion:", font=("Arial", 12)).pack(anchor="w", padx=10)
        self.audio_emoji_label = ttk.Label(frame, textvariable=self.audio_pred_icon, font=("Arial", 40))
        self.audio_emoji_label.pack(anchor="w", padx=10)
        self.audio_label_label = ttk.Label(frame, textvariable=self.audio_pred_label, font=("Arial", 16, "bold"))
        self.audio_label_label.pack(anchor="w", padx=10, pady=(0, 10))
        self.audio_probs_frame = ttk.Frame(frame)
        self.audio_probs_frame.pack(anchor="w", fill="x", padx=10, pady=(10, 0))
        self.audio_prob_bars = {}
        for i, label in enumerate(AUDIO_LABELS):
            bar = ttk.Progressbar(self.audio_probs_frame, orient="horizontal", length=120, mode="determinate", maximum=1.0)
            bar.grid(row=i, column=1, sticky="ew", padx=5, pady=2)
            ttk.Label(self.audio_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label.title()}").grid(row=i, column=0, sticky="w")
            self.audio_prob_bars[label] = bar
        ttk.Label(frame, text="Transcript:", font=("Arial", 10, "italic")).pack(anchor="w", padx=10, pady=(10, 0))
        self.audio_transcript_label = ttk.Label(frame, textvariable=self.audio_transcript, font=("Arial", 10), wraplength=400, justify="left")
        self.audio_transcript_label.pack(anchor="w", padx=10, pady=(0, 10))

        self.is_recording = False
        self.audio_data = []
        self.last_audio_file = None

    def toggle_audio_record(self):
        if self.is_recording:
            self.stop_audio_recording()
        else:
            self.start_audio_recording()

    def start_audio_recording(self):
        self.is_recording = True
        self.audio_data = []
        self.audio_record_btn.config(text="⏹️ Stop Recording")
        self.audio_status.set("Recording...")
        self.audio_play_btn.config(state="disabled")
        self.audio_transcript.set("")
        def callback(indata, frames, time, status):
            if status:
                print(status)
            indata = indata * self.record_gain.get()
            self.audio_data.append(indata.copy())
        self.audio_stream = sd.InputStream(
            samplerate=AUDIO_SR,
            channels=1,
            dtype='float32',
            callback=callback
        )
        self.audio_stream.start()
        threading.Timer(AUDIO_DURATION, self.stop_audio_recording).start()

    def stop_audio_recording(self):
        if not self.is_recording:
            return
        self.is_recording = False
        self.audio_record_btn.config(text="🎙️ Record Audio")
        self.audio_status.set("Processing...")
        if hasattr(self, 'audio_stream'):
            self.audio_stream.stop()
            self.audio_stream.close()
        if self.audio_data:
            recorded_audio = np.concatenate(self.audio_data, axis=0)
            temp_file = "temp_recorded_audio.wav"
            sf.write(temp_file, recorded_audio, AUDIO_SR)
            self.last_audio_file = temp_file
            self.audio_play_btn.config(state="normal")
            threading.Thread(target=self.audio_predict_and_transcribe_thread, args=(temp_file,)).start()
        else:
            self.audio_status.set("No audio recorded.")
            self.audio_play_btn.config(state="disabled")

    def play_audio(self):
        if self.last_audio_file and os.path.exists(self.last_audio_file):
            data, fs = sf.read(self.last_audio_file, dtype='float32')
            data = data * self.playback_gain.get()
            sd.play(data, fs)
            sd.wait()

    def audio_predict_and_transcribe_thread(self, temp_file):
        label, probs = predict_audio_emotion(temp_file)
        icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
        self.audio_pred_label.set(label.title())
        self.audio_pred_icon.set(icon)
        self.audio_pred_probs = probs
        transcript = transcribe_audio(temp_file)
        self.audio_transcript.set(transcript)
        if os.path.exists(temp_file):
            os.remove(temp_file)
        def update_bars():
            if probs is not None:
                for i, l in enumerate(AUDIO_LABELS):
                    self.audio_prob_bars[l]['value'] = probs[i]
            self.audio_status.set("Ready")
        self.root.after(0, update_bars)

    # --- Text Panel ---
    def build_text_panel(self, frame):
        ttk.Label(frame, text="Text Emotion", font=("Arial", 15, "bold")).pack(anchor="w", padx=10, pady=(0, 5))
        ttk.Label(frame, textvariable=self.text_question, font=("Arial", 12, "italic"), foreground="#0077b6").pack(anchor="w", padx=10, pady=(0, 5))
        self.text_entry = tk.Text(frame, height=4, width=50, font=("Arial", 12))
        self.text_entry.pack(anchor="w", padx=10, pady=(0, 5))
        self.text_predict_btn = ttk.Button(frame, text="Analyze Text", command=self.text_predict)
        self.text_predict_btn.pack(anchor="w", padx=10, pady=(0, 5))
        ttk.Label(frame, text="Predicted Emotion:", font=("Arial", 12)).pack(anchor="w", padx=10)
        self.text_emoji_label = ttk.Label(frame, textvariable=self.text_pred_icon, font=("Arial", 40))
        self.text_emoji_label.pack(anchor="w", padx=10)
        self.text_label_label = ttk.Label(frame, textvariable=self.text_pred_label, font=("Arial", 16, "bold"))
        self.text_label_label.pack(anchor="w", padx=10, pady=(0, 10))
        self.text_probs_frame = ttk.Frame(frame)
        self.text_probs_frame.pack(anchor="w", fill="x", padx=10, pady=(10, 0))
        self.text_prob_bars = {}
        for i, label in enumerate(TEXT_LABELS):
            bar = ttk.Progressbar(self.text_probs_frame, orient="horizontal", length=120, mode="determinate", maximum=1.0)
            bar.grid(row=i, column=1, sticky="ew", padx=5, pady=2)
            ttk.Label(self.text_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label.title()}").grid(row=i, column=0, sticky="w")
            self.text_prob_bars[label] = bar

    def text_predict(self):
        text = self.text_entry.get("1.0", "end").strip()
        if not text:
            messagebox.showwarning("Input Required", "Please enter some text.")
            return
        label, probs = predict_text_emotion(text)
        icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
        self.text_pred_label.set(label.title())
        self.text_pred_icon.set(icon)
        self.text_pred_probs = probs
        def update_bars():
            if probs is not None:
                for i, l in enumerate(TEXT_LABELS):
                    self.text_prob_bars[l]['value'] = probs[i]
        self.root.after(0, update_bars)

if __name__ == "__main__":
    root = ThemedTk(theme="arc")
    app = EmotionApp(root)
    root.mainloop()
