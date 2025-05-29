# import os
# import tkinter as tk
# from tkinter import ttk, messagebox
# from ttkthemes import ThemedTk
# import cv2
# import numpy as np
# import librosa
# import sounddevice as sd
# import soundfile as sf
# import tensorflow as tf
# import pickle
# import torch
# from transformers import DistilBertTokenizerFast, DistilBertForSequenceClassification
# from PIL import Image, ImageTk
# import threading
# import time
# import random
# import speech_recognition as sr

# # --- Paths and Constants ---
# BASE_DIR = os.path.dirname(__file__)
# FACE_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'emotion_recognition_model_100.h5')
# AUDIO_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'Speech Emotion Recognition Minor Project', 'LSTM Model', 'speech_emotion_recognition_model_lstm.h5')
# SCALER_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'Speech Emotion Recognition Minor Project', 'LSTM Model', 'scalerLSTM.pkl')
# TEXT_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'emotion-distilbert-model')

# FACE_IMG_SIZE = (48, 48)
# AUDIO_DURATION = 4
# AUDIO_SR = 16000

# FACE_LABELS = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']
# AUDIO_LABELS = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']
# TEXT_LABELS = ['anger', 'joy', 'sadness', 'fear', 'love', 'surprise']

# EMOTION_ICONS = {
#     'angry': '😡', 'disgust': '🤢', 'fear': '😨', 'happy': '😄', 'neutral': '😐',
#     'sad': '😢', 'surprise': '😲', 'joy': '😄', 'sadness': '😢', 'anger': '😡', 'love': '❤️', 'default': '❓'
# }

# AUDIO_QUESTIONS = [
#     "How are you feeling today?",
#     "What is one thing that's on your mind?",
#     "Describe your mood in a few words.",
#     "How has your week been so far?",
#     "Is there something that's been bothering you?"
# ]
# TEXT_QUESTIONS = [
#     "Write a few words about how you feel right now.",
#     "Describe your current mood.",
#     "Is there anything you'd like to express today?",
#     "Share something that's on your mind.",
#     "How have you been emotionally?"
# ]

# # --- Load Models ---
# def safe_load_model(load_func, *args, **kwargs):
#     try:
#         return load_func(*args, **kwargs)
#     except Exception as e:
#         print(f"Error loading model: {e}")
#         return None

# face_model = safe_load_model(tf.keras.models.load_model, FACE_MODEL_PATH)
# try:
#     with open(SCALER_PATH, 'rb') as f:
#         audio_scaler = pickle.load(f)
#     audio_model = tf.keras.models.load_model(AUDIO_MODEL_PATH)
# except Exception as e:
#     print(f"Error loading audio model/scaler: {e}")
#     audio_model = None
#     audio_scaler = None

# try:
#     text_tokenizer = DistilBertTokenizerFast.from_pretrained(TEXT_MODEL_PATH)
#     text_model = DistilBertForSequenceClassification.from_pretrained(TEXT_MODEL_PATH)
#     text_model.eval()
# except Exception as e:
#     print(f"Error loading text model/tokenizer: {e}")
#     text_tokenizer = None
#     text_model = None

# # --- Utility Functions ---
# def detect_face(frame):
#     face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
#     gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
#     faces = face_cascade.detectMultiScale(gray, 1.1, 4)
#     if len(faces) > 0:
#         x, y, w, h = max(faces, key=lambda rect: rect[2]*rect[3])
#         return gray[y:y+h, x:x+w], (x, y, w, h)
#     return None, None

# def predict_face_emotion(img_array):
#     if face_model is None:
#         return "Model not loaded", None
#     img = img_array.astype('float32') / 255.0
#     img = np.expand_dims(img, axis=(0, -1))
#     preds = face_model.predict(img, verbose=0)
#     label = FACE_LABELS[np.argmax(preds)]
#     return label, preds[0]

# def extract_audio_features(y, sr):
#     zcr = np.mean(librosa.feature.zero_crossing_rate(y=y).T, axis=0)
#     stft = np.abs(librosa.stft(y))
#     chroma_stft = np.mean(librosa.feature.chroma_stft(S=stft, sr=sr).T, axis=0)
#     mfcc = np.mean(librosa.feature.mfcc(y=y, sr=sr).T, axis=0)
#     rms = np.mean(librosa.feature.rms(y=y).T, axis=0)
#     mel = np.mean(librosa.feature.melspectrogram(y=y, sr=sr).T, axis=0)
#     return np.hstack((zcr, chroma_stft, mfcc, rms, mel))

# def predict_audio_emotion(file_path):
#     if audio_model is None or audio_scaler is None:
#         return "Model not loaded", None
#     try:
#         y, sr = librosa.load(file_path, sr=AUDIO_SR)
#         features = extract_audio_features(y, sr)
#         features_scaled = audio_scaler.transform(features.reshape(1, -1))
#         features_reshaped = np.expand_dims(features_scaled, axis=2)
#         preds = audio_model.predict(features_reshaped, verbose=0)
#         label = AUDIO_LABELS[np.argmax(preds)]
#         return label, preds[0]
#     except Exception as e:
#         print(f"Error in audio prediction: {e}")
#         return "Error", None

# def predict_text_emotion(text):
#     if text_model is None or text_tokenizer is None:
#         return "Model not loaded", None
#     try:
#         inputs = text_tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=128)
#         with torch.no_grad():
#             outputs = text_model(**inputs)
#             logits = outputs.logits
#             pred = torch.argmax(logits, dim=1).item()
#             return TEXT_LABELS[pred], logits[0].softmax(dim=0).numpy()
#     except Exception as e:
#         print(f"Error predicting text emotion: {e}")
#         return "Error", None

# def transcribe_audio(file_path):
#     try:
#         recognizer = sr.Recognizer()
#         with sr.AudioFile(file_path) as source:
#             audio_data = recognizer.record(source)
#         return recognizer.recognize_google(audio_data)
#     except Exception as e:
#         print(f"Speech recognition error: {e}")
#         return ""

# # --- GUI Application ---
# class EmotionApp:
#     def __init__(self, root):
#         self.root = root
#         self.root.title("Multimodal Emotion Dashboard")
#         self.root.geometry("1200x700")
#         self.root.minsize(1000, 600)
#         self.root.protocol("WM_DELETE_WINDOW", self.on_close)

#         style = ttk.Style(self.root)
#         style.theme_use('arc')

#         # --- Tkinter Variables ---
#         self.face_pred_icon = tk.StringVar(value='❓')
#         self.face_pred_label = tk.StringVar(value='Detecting...')
#         self.audio_pred_icon = tk.StringVar(value='❓')
#         self.audio_pred_label = tk.StringVar(value='Not predicted')
#         self.audio_status = tk.StringVar(value="Ready")
#         self.text_pred_icon = tk.StringVar(value='❓')
#         self.text_pred_label = tk.StringVar(value='Not predicted')
#         self.audio_question = tk.StringVar(value=random.choice(AUDIO_QUESTIONS))
#         self.text_question = tk.StringVar(value=random.choice(TEXT_QUESTIONS))
#         self.audio_transcript = tk.StringVar(value="")
#         self.audio_play_btn_state = tk.StringVar(value="disabled")
#         self.record_gain = tk.DoubleVar(value=1.0)
#         self.playback_gain = tk.DoubleVar(value=1.0)

#         # --- Layout ---
#         self.main_frame = ttk.Frame(self.root, padding=10)
#         self.main_frame.pack(fill='both', expand=True)

#         # Left: Camera & Face
#         self.left_frame = ttk.Frame(self.main_frame)
#         self.left_frame.pack(side="left", fill="both", expand=True, padx=(0, 10))

#         # Right: Audio (top) and Text (bottom)
#         self.right_frame = ttk.Frame(self.main_frame)
#         self.right_frame.pack(side="right", fill="both", expand=True)

#         self.right_top = ttk.Frame(self.right_frame)
#         self.right_top.pack(side="top", fill="both", expand=True, pady=(0, 5))
#         self.right_bottom = ttk.Frame(self.right_frame)
#         self.right_bottom.pack(side="bottom", fill="both", expand=True, pady=(5, 0))

#         self.build_face_panel(self.left_frame)
#         self.build_audio_panel(self.right_top)
#         self.build_text_panel(self.right_bottom)

#         # For camera
#         self.cap = cv2.VideoCapture(0)
#         self.face_update_interval = 100  # ms
#         self.face_last_pred_time = 0
#         self.face_pred_probs = None

#         self.update_camera()

#     # --- Face Panel ---
#     def build_face_panel(self, parent):
#         title = ttk.Label(parent, text="Camera & Face Emotion", font=("Arial", 16, "bold"))
#         title.pack(anchor="center", pady=(0, 10))
#         self.face_canvas = tk.Label(parent, borderwidth=2, relief="groove")
#         self.face_canvas.pack(anchor="center", padx=10, pady=10, expand=True)
#         info_frame = ttk.Frame(parent)
#         info_frame.pack(anchor="center", pady=(10, 0))
#         ttk.Label(info_frame, text="Predicted Emotion:", font=("Arial", 12)).pack(anchor="w")
#         self.face_emoji_label = ttk.Label(info_frame, textvariable=self.face_pred_icon, font=("Arial", 40))
#         self.face_emoji_label.pack(anchor="w")
#         self.face_label_label = ttk.Label(info_frame, textvariable=self.face_pred_label, font=("Arial", 16, "bold"))
#         self.face_label_label.pack(anchor="w", pady=(0, 10))

#         self.face_probs_frame = ttk.Frame(info_frame)
#         self.face_probs_frame.pack(anchor="w", fill="x", pady=(10, 0))
#         self.face_prob_bars = {}
#         for i, label in enumerate(FACE_LABELS):
#             bar = ttk.Progressbar(self.face_probs_frame, orient="horizontal", length=120, mode="determinate", maximum=1.0)
#             bar.grid(row=i, column=1, sticky="ew", padx=5, pady=2)
#             ttk.Label(self.face_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label.title()}").grid(row=i, column=0, sticky="w")
#             self.face_prob_bars[label] = bar

#     def update_camera(self):
#         ret, frame = self.cap.read()
#         if ret:
#             display_frame = frame.copy()
#             face_img, face_rect = detect_face(frame)
#             now = time.time()
#             if face_img is not None and now - self.face_last_pred_time > 0.8:
#                 resized = cv2.resize(face_img, FACE_IMG_SIZE)
#                 threading.Thread(target=self.face_predict_thread, args=(resized,)).start()
#                 self.face_last_pred_time = now
#                 if face_rect:
#                     x, y, w, h = face_rect
#                     cv2.rectangle(display_frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
#             rgb = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
#             img = Image.fromarray(rgb)
#             img = img.resize((400, 300))
#             self.face_photo = ImageTk.PhotoImage(image=img)
#             self.face_canvas.config(image=self.face_photo)
#         self.root.after(self.face_update_interval, self.update_camera)

#     def face_predict_thread(self, face_img):
#         label, probs = predict_face_emotion(face_img)
#         icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
#         self.face_pred_label.set(label.title())
#         self.face_pred_icon.set(icon)
#         self.face_pred_probs = probs
#         def update_bars():
#             if probs is not None:
#                 for i, l in enumerate(FACE_LABELS):
#                     self.face_prob_bars[l]['value'] = probs[i]
#         self.root.after(0, update_bars)

#     # --- Audio Panel ---
#     def build_audio_panel(self, frame):
#         ttk.Label(frame, text="Audio Emotion", font=("Arial", 15, "bold")).pack(anchor="w", padx=10, pady=(0, 5))
#         ttk.Label(frame, textvariable=self.audio_question, font=("Arial", 12, "italic"), foreground="#0077b6").pack(anchor="w", padx=10, pady=(0, 5))

#         self.audio_record_btn = ttk.Button(frame, text="🎙️ Record Audio", command=self.toggle_audio_record)
#         self.audio_record_btn.pack(anchor="w", padx=10, pady=5)

#         self.audio_play_btn = ttk.Button(frame, text="▶️ Play Recording", command=self.play_audio, state="disabled")
#         self.audio_play_btn.pack(anchor="w", padx=10, pady=(0, 5))

#         # Mic Gain Slider
#         ttk.Label(frame, text="Mic Gain (Recording)").pack(anchor="w", padx=10)
#         self.record_slider = ttk.Scale(frame, from_=0.5, to=3.0, orient="horizontal",
#                                        variable=self.record_gain, length=150)
#         self.record_slider.pack(anchor="w", padx=10, pady=(0, 5))

#         # Playback Gain Slider
#         ttk.Label(frame, text="Playback Volume").pack(anchor="w", padx=10)
#         self.playback_slider = ttk.Scale(frame, from_=0.0, to=2.0, orient="horizontal",
#                                          variable=self.playback_gain, length=150)
#         self.playback_slider.pack(anchor="w", padx=10, pady=(0, 5))

#         self.audio_status_label = ttk.Label(frame, textvariable=self.audio_status, font=("Arial", 10))
#         self.audio_status_label.pack(anchor="w", padx=10, pady=(0, 5))

#         ttk.Label(frame, text="Predicted Emotion:", font=("Arial", 12)).pack(anchor="w", padx=10)
#         self.audio_emoji_label = ttk.Label(frame, textvariable=self.audio_pred_icon, font=("Arial", 40))
#         self.audio_emoji_label.pack(anchor="w", padx=10)
#         self.audio_label_label = ttk.Label(frame, textvariable=self.audio_pred_label, font=("Arial", 16, "bold"))
#         self.audio_label_label.pack(anchor="w", padx=10, pady=(0, 10))

#         self.audio_probs_frame = ttk.Frame(frame)
#         self.audio_probs_frame.pack(anchor="w", fill="x", padx=10, pady=(10, 0))
#         self.audio_prob_bars = {}
#         for i, label in enumerate(AUDIO_LABELS):
#             bar = ttk.Progressbar(self.audio_probs_frame, orient="horizontal", length=120, mode="determinate", maximum=1.0)
#             bar.grid(row=i, column=1, sticky="ew", padx=5, pady=2)
#             ttk.Label(self.audio_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label.title()}").grid(row=i, column=0, sticky="w")
#             self.audio_prob_bars[label] = bar

#         ttk.Label(frame, text="Transcript:", font=("Arial", 10, "italic")).pack(anchor="w", padx=10, pady=(10, 0))
#         self.audio_transcript_label = ttk.Label(frame, textvariable=self.audio_transcript, font=("Arial", 10), wraplength=400, justify="left")
#         self.audio_transcript_label.pack(anchor="w", padx=10, pady=(0, 10))

#         self.is_recording = False
#         self.audio_data = []
#         self.last_audio_file = None

#     def toggle_audio_record(self):
#         if self.is_recording:
#             self.stop_audio_recording()
#         else:
#             self.start_audio_recording()

#     def start_audio_recording(self):
#         self.is_recording = True
#         self.audio_data = []
#         self.audio_record_btn.config(text="⏹️ Stop Recording")
#         self.audio_status.set("Recording...")
#         self.audio_play_btn.config(state="disabled")
#         self.audio_transcript.set("")
#         def callback(indata, frames, time, status):
#             if status:
#                 print(status)
#             # Apply mic gain
#             indata = indata * self.record_gain.get()
#             self.audio_data.append(indata.copy())
#         self.audio_stream = sd.InputStream(
#             samplerate=AUDIO_SR,
#             channels=1,
#             dtype='float32',
#             callback=callback
#         )
#         self.audio_stream.start()
#         threading.Timer(AUDIO_DURATION, self.stop_audio_recording).start()

#     def stop_audio_recording(self):
#         if not self.is_recording:
#             return
#         self.is_recording = False
#         self.audio_record_btn.config(text="🎙️ Record Audio")
#         self.audio_status.set("Processing...")
#         if hasattr(self, 'audio_stream'):
#             self.audio_stream.stop()
#             self.audio_stream.close()
#         if self.audio_data:
#             recorded_audio = np.concatenate(self.audio_data, axis=0)
#             temp_file = "temp_recorded_audio.wav"
#             sf.write(temp_file, recorded_audio, AUDIO_SR)
#             self.last_audio_file = temp_file
#             self.audio_play_btn.config(state="normal")
#             threading.Thread(target=self.audio_predict_and_transcribe_thread, args=(temp_file,)).start()
#         else:
#             self.audio_status.set("No audio recorded.")
#             self.audio_play_btn.config(state="disabled")

#     def play_audio(self):
#         if self.last_audio_file and os.path.exists(self.last_audio_file):
#             data, fs = sf.read(self.last_audio_file, dtype='float32')
#             # Apply playback gain
#             data = data * self.playback_gain.get()
#             sd.play(data, fs)
#             sd.wait()

#     def audio_predict_and_transcribe_thread(self, temp_file):
#         # Predict emotion (do NOT delete file yet)
#         label, probs = predict_audio_emotion(temp_file)
#         icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
#         self.audio_pred_label.set(label.title())
#         self.audio_pred_icon.set(icon)
#         self.audio_pred_probs = probs
#         # Transcribe audio
#         transcript = transcribe_audio(temp_file)
#         self.audio_transcript.set(transcript)
#         # Now safe to delete the file
#         if os.path.exists(temp_file):
#             os.remove(temp_file)
#         def update_bars():
#             if probs is not None:
#                 for i, l in enumerate(AUDIO_LABELS):
#                     self.audio_prob_bars[l]['value'] = probs[i]
#             self.audio_status.set("Ready")
#         self.root.after(0, update_bars)

#     # --- Text Panel ---
#     def build_text_panel(self, frame):
#         ttk.Label(frame, text="Text Emotion", font=("Arial", 15, "bold")).pack(anchor="w", padx=10, pady=(0, 5))
#         ttk.Label(frame, textvariable=self.text_question, font=("Arial", 12, "italic"), foreground="#0077b6").pack(anchor="w", padx=10, pady=(0, 5))
#         self.text_input = tk.Text(frame, height=4, width=50, font=("Arial", 12))
#         self.text_input.pack(anchor="w", padx=10, pady=10)

#         self.text_predict_btn = ttk.Button(frame, text="🔎 Predict Text Emotion", command=self.text_predict)
#         self.text_predict_btn.pack(anchor="w", padx=10, pady=(0, 10))

#         ttk.Label(frame, text="Predicted Emotion:", font=("Arial", 12)).pack(anchor="w", padx=10)
#         self.text_emoji_label = ttk.Label(frame, textvariable=self.text_pred_icon, font=("Arial", 40))
#         self.text_emoji_label.pack(anchor="w", padx=10)
#         self.text_label_label = ttk.Label(frame, textvariable=self.text_pred_label, font=("Arial", 16, "bold"))
#         self.text_label_label.pack(anchor="w", padx=10, pady=(0, 10))

#         self.text_probs_frame = ttk.Frame(frame)
#         self.text_probs_frame.pack(anchor="w", fill="x", padx=10, pady=(10, 0))
#         self.text_prob_bars = {}
#         for i, label in enumerate(TEXT_LABELS):
#             bar = ttk.Progressbar(self.text_probs_frame, orient="horizontal", length=120, mode="determinate", maximum=1.0)
#             bar.grid(row=i, column=1, sticky="ew", padx=5, pady=2)
#             ttk.Label(self.text_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label.title()}").grid(row=i, column=0, sticky="w")
#             self.text_prob_bars[label] = bar

#     def text_predict(self):
#         text = self.text_input.get("1.0", tk.END).strip()
#         if not text:
#             messagebox.showinfo("Input Required", "Please enter some text.")
#             return
#         self.text_predict_btn.config(state="disabled")
#         self.text_pred_label.set("Predicting...")
#         self.text_pred_icon.set(EMOTION_ICONS['default'])
#         threading.Thread(target=self.text_predict_thread, args=(text,)).start()

#     def text_predict_thread(self, text):
#         label, probs = predict_text_emotion(text)
#         icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
#         self.text_pred_label.set(label.title())
#         self.text_pred_icon.set(icon)
#         self.text_pred_probs = probs
#         def update_bars():
#             if probs is not None:
#                 for i, l in enumerate(TEXT_LABELS):
#                     self.text_prob_bars[l]['value'] = probs[i]
#             self.text_predict_btn.config(state="normal")
#         self.root.after(0, update_bars)

#     def on_close(self):
#         if hasattr(self, 'cap') and self.cap.isOpened():
#             self.cap.release()
#         self.root.destroy()

# if __name__ == "__main__":
#     tf.config.set_visible_devices([], 'GPU')
#     root = ThemedTk(theme="arc")
#     app = EmotionApp(root)
#     root.mainloop()
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
    "How are you feeling today?"
    # "What is one thing that's on your mind?",
    # "Describe your mood in a few words.",
    # "How has your week been so far?",
    # "Is there something that's been bothering you?"
]
TEXT_QUESTIONS = [
    "How are you feeling today?"
    # "Write a few words about how you feel right now.",
    # "Describe your current mood.",
    # "Is there anything you'd like to express today?",
    # "Share something that's on your mind.",
    # "How have you been emotionally?"
]

# --- Load Models ---
def safe_load_model(load_func, *args, **kwargs):
    try:
        return load_func(*args, **kwargs)
    except Exception as e:
        print(f"Error loading model: {e}")
        return None

face_model = safe_load_model(tf.keras.models.load_model, FACE_MODEL_PATH)
try:
    with open(SCALER_PATH, 'rb') as f:
        audio_scaler = pickle.load(f)
    audio_model = tf.keras.models.load_model(AUDIO_MODEL_PATH)
except Exception as e:
    print(f"Error loading audio model/scaler: {e}")
    audio_model = None
    audio_scaler = None

try:
    text_tokenizer = DistilBertTokenizerFast.from_pretrained(TEXT_MODEL_PATH)
    text_model = DistilBertForSequenceClassification.from_pretrained(TEXT_MODEL_PATH)
    text_model.eval()
except Exception as e:
    print(f"Error loading text model/tokenizer: {e}")
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
    img = img_array.astype('float32') / 255.0
    img = np.expand_dims(img, axis=(0, -1))
    preds = face_model.predict(img, verbose=0)
    label = FACE_LABELS[np.argmax(preds)]
    return label, preds[0]

def extract_audio_features(y, sr):
    zcr = np.mean(librosa.feature.zero_crossing_rate(y=y).T, axis=0)
    stft = np.abs(librosa.stft(y))
    chroma_stft = np.mean(librosa.feature.chroma_stft(S=stft, sr=sr).T, axis=0)
    mfcc = np.mean(librosa.feature.mfcc(y=y, sr=sr).T, axis=0)
    rms = np.mean(librosa.feature.rms(y=y).T, axis=0)
    mel = np.mean(librosa.feature.melspectrogram(y=y, sr=sr).T, axis=0)
    return np.hstack((zcr, chroma_stft, mfcc, rms, mel))

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
        return "Error", None

def transcribe_audio(file_path):
    try:
        recognizer = sr.Recognizer()
        

        with sr.AudioFile(file_path) as source:
            audio_data = recognizer.record(source)

        if len(audio_data.frame_data) == 0:
            print("Audio is empty or too short.")
            return ""

        return recognizer.recognize_google(audio_data, language='en-US')

    except sr.RequestError:
        print("Could not request results from Google; check your internet.")
        return ""

    except sr.UnknownValueError:
        print("Speech was unintelligible.")
        return ""

    except Exception as e:
        import traceback
        print("Speech recognition error:")
        traceback.print_exc()
        return ""


# --- GUI Application ---
class EmotionApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Multimodal Emotion Dashboard")
        self.root.geometry("1280x800")
        self.root.minsize(1000, 600)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

        style = ttk.Style(self.root)
        style.theme_use('arc')

        # Initialize before any UI methods
        self.is_recording = False
        self.audio_data = []
        self.last_audio_file = None

        # --- Tkinter Variables ---
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
        self.record_gain = tk.DoubleVar(value=1.0)
        self.playback_gain = tk.DoubleVar(value=1.0)
        self.aggregate_icon = tk.StringVar(value='❓')
        self.aggregate_label = tk.StringVar(value='Not calculated')

        # --- Layout ---
        self.main_frame = ttk.Frame(self.root, padding=15)
        self.main_frame.pack(fill='both', expand=True)

        # Create sections
        self.create_face_section()
        self.create_audio_section()
        self.create_text_section()
        self.create_aggregate_section()

        # Camera setup
        self.cap = cv2.VideoCapture(0)
        self.face_update_interval = 100
        self.face_last_pred_time = 0
        self.face_pred_probs = None
        self.update_camera()

    def create_face_section(self):
        self.face_frame = ttk.LabelFrame(self.main_frame, text="Camera & Face Emotion", padding=10)
        self.face_frame.grid(row=0, column=0, padx=5, pady=5, sticky="nsew")
        self.main_frame.grid_rowconfigure(0, weight=1)
        self.main_frame.grid_columnconfigure(0, weight=1)

        self.face_canvas = tk.Label(self.face_frame, borderwidth=2, relief="groove")
        self.face_canvas.pack(anchor="center", padx=10, pady=10, expand=True)

        face_info = ttk.Frame(self.face_frame)
        face_info.pack(pady=10)
        ttk.Label(face_info, text="Predicted Emotion:", style="Section.TLabel").grid(row=0, column=0)
        self.face_emoji_label = ttk.Label(face_info, textvariable=self.face_pred_icon, font=("Arial", 32))
        self.face_emoji_label.grid(row=0, column=1, padx=10)
        self.face_label_label = ttk.Label(face_info, textvariable=self.face_pred_label, style="Emotion.TLabel")
        self.face_label_label.grid(row=1, column=0, columnspan=2, pady=5)

        self.face_probs_frame = ttk.Frame(self.face_frame)
        self.face_probs_frame.pack(fill="x", padx=5)
        self.face_prob_bars = {}
        for i, label in enumerate(FACE_LABELS):
            ttk.Label(self.face_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label}").grid(
                row=i, column=0, sticky="w")
            bar = ttk.Progressbar(self.face_probs_frame, orient="horizontal",
                                  style="ProbBar.Horizontal.TProgressbar",
                                  length=200, mode="determinate")
            bar.grid(row=i, column=1, sticky="ew", padx=5)
            self.face_prob_bars[label] = bar

    def create_audio_section(self):
        self.audio_frame = ttk.LabelFrame(self.main_frame, text="Audio Emotion Analysis", padding=10)
        self.audio_frame.grid(row=0, column=1, padx=5, pady=5, sticky="nsew")
        self.main_frame.grid_rowconfigure(0, weight=1)
        self.main_frame.grid_columnconfigure(1, weight=1)

        ttk.Label(self.audio_frame, textvariable=self.audio_question, font=("Arial", 12, "italic")).pack()
        btn_frame = ttk.Frame(self.audio_frame)
        btn_frame.pack(pady=10)
        self.audio_record_btn = ttk.Button(btn_frame, text="🎙️ Record", command=self.toggle_audio_record)
        self.audio_record_btn.grid(row=0, column=0, padx=5)
        self.audio_play_btn = ttk.Button(btn_frame, text="▶️ Play", command=self.play_audio, state="disabled")
        self.audio_play_btn.grid(row=0, column=1, padx=5)

        slider_frame = ttk.Frame(self.audio_frame)
        slider_frame.pack(fill="x", pady=5)
        ttk.Label(slider_frame, text="Mic Gain").grid(row=0, column=0)
        self.record_slider = ttk.Scale(slider_frame, from_=0.5, to=3.0, orient="horizontal",
                                       variable=self.record_gain, length=150)
        self.record_slider.grid(row=0, column=1, padx=5)
        ttk.Label(slider_frame, text="Playback").grid(row=1, column=0)
        self.playback_slider = ttk.Scale(slider_frame, from_=0.0, to=2.0, orient="horizontal",
                                         variable=self.playback_gain, length=150)
        self.playback_slider.grid(row=1, column=1, padx=5)

        self.audio_status_label = ttk.Label(self.audio_frame, textvariable=self.audio_status)
        self.audio_status_label.pack()

        ttk.Label(self.audio_frame, text="Predicted Emotion:", style="Section.TLabel").pack()
        self.audio_emoji_label = ttk.Label(self.audio_frame, textvariable=self.audio_pred_icon, font=("Arial", 32))
        self.audio_emoji_label.pack()
        self.audio_label_label = ttk.Label(self.audio_frame, textvariable=self.audio_pred_label, style="Emotion.TLabel")
        self.audio_label_label.pack()

        self.audio_probs_frame = ttk.Frame(self.audio_frame)
        self.audio_probs_frame.pack(fill="x", padx=5)
        self.audio_prob_bars = {}
        for i, label in enumerate(AUDIO_LABELS):
            ttk.Label(self.audio_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label}").grid(
                row=i, column=0, sticky="w")
            bar = ttk.Progressbar(self.audio_probs_frame, orient="horizontal",
                                  style="ProbBar.Horizontal.TProgressbar",
                                  length=200, mode="determinate")
            bar.grid(row=i, column=1, sticky="ew", padx=5)
            self.audio_prob_bars[label] = bar

        ttk.Label(self.audio_frame, text="Transcript:", font=("Arial", 10, "italic")).pack()
        self.audio_transcript_label = ttk.Label(self.audio_frame, textvariable=self.audio_transcript,
                                              wraplength=300, justify="left")
        self.audio_transcript_label.pack()

    def create_text_section(self):
        self.text_frame = ttk.LabelFrame(self.main_frame, text="Text Emotion Analysis", padding=10)
        self.text_frame.grid(row=1, column=0, padx=5, pady=5, sticky="nsew")
        self.main_frame.grid_rowconfigure(1, weight=1)

        ttk.Label(self.text_frame, textvariable=self.text_question, font=("Arial", 12, "italic")).pack()
        self.text_input = tk.Text(self.text_frame, height=5, width=40, font=("Arial", 12))
        self.text_input.pack(pady=5)

        self.text_predict_btn = ttk.Button(self.text_frame, text="🔎 Predict", command=self.text_predict)
        self.text_predict_btn.pack()

        ttk.Label(self.text_frame, text="Predicted Emotion:", style="Section.TLabel").pack()
        self.text_emoji_label = ttk.Label(self.text_frame, textvariable=self.text_pred_icon, font=("Arial", 32))
        self.text_emoji_label.pack()
        self.text_label_label = ttk.Label(self.text_frame, textvariable=self.text_pred_label, style="Emotion.TLabel")
        self.text_label_label.pack()

        self.text_probs_frame = ttk.Frame(self.text_frame)
        self.text_probs_frame.pack(fill="x", padx=5)
        self.text_prob_bars = {}
        for i, label in enumerate(TEXT_LABELS):
            ttk.Label(self.text_probs_frame, text=f"{EMOTION_ICONS.get(label, '')} {label}").grid(
                row=i, column=0, sticky="w")
            bar = ttk.Progressbar(self.text_probs_frame, orient="horizontal",
                                  style="ProbBar.Horizontal.TProgressbar",
                                  length=200, mode="determinate")
            bar.grid(row=i, column=1, sticky="ew", padx=5)
            self.text_prob_bars[label] = bar

    def create_aggregate_section(self):
        style = ttk.Style()
        style.configure("Accent.TButton", font=("Arial", 12, "bold"), padding=10)

        self.aggregate_btn = ttk.Button(self.main_frame, text="📊 Aggregate Emotion",
                                      command=self.calculate_aggregate, style="Accent.TButton")
        self.aggregate_btn.grid(row=2, column=0, columnspan=2, pady=10)

        self.aggregate_frame = ttk.Frame(self.main_frame, padding=10)
        self.aggregate_frame.grid(row=3, column=0, columnspan=2, sticky="ew")

        ttk.Label(self.aggregate_frame, text="Aggregate Emotion:", style="Section.TLabel").pack()
        self.aggregate_display = ttk.Frame(self.aggregate_frame)
        self.aggregate_display.pack()

        self.aggregate_emoji = ttk.Label(self.aggregate_display, textvariable=self.aggregate_icon,
                                        font=("Arial", 40))
        self.aggregate_emoji.pack(side="left")

        self.aggregate_result = ttk.Label(self.aggregate_display,
                                          textvariable=self.aggregate_label,
                                          style="Emotion.TLabel")
        self.aggregate_result.pack(side="left", padx=10)

    def calculate_aggregate(self):
        if any(x is None for x in (self.face_pred_probs, self.audio_pred_probs, self.text_pred_probs)):

            messagebox.showinfo("Missing Data", "Please complete all three emotion predictions first.")
            return

        try:
            # Define weights for each modality (can be adjusted based on empirical reliability)
            weights = {
                'face': 0.5,
                'audio': 0.15,
                'text': 0.35
            }
            
            # Map text emotions to face/audio emotion space
            # More accurate mapping between text model and face/audio models
            text_to_common = {
                'anger': 'angry',     # Anger maps to angry
                'joy': 'happy',       # Joy maps to happy  
                'sadness': 'sad',     # Sadness maps to sad
                'fear': 'fear',       # Fear maps to fear
                'love': 'happy',      # Love maps more to happy than neutral
                'surprise': 'surprise' # Surprise maps to surprise
            }
            
            # Create a standardized emotion space for consistent comparison
            common_emotions = FACE_LABELS  # Using the face labels as our common emotion space
            
            # Create normalized probability distributions in common emotion space
            face_probs = self.face_pred_probs  # Already in common space
            audio_probs = self.audio_pred_probs  # Already in common space
            
            # Map text probabilities to common emotion space
            text_probs_mapped = np.zeros(len(common_emotions))
            for i, emotion in enumerate(TEXT_LABELS):
                # Get the corresponding common emotion
                common_emotion = text_to_common[emotion]
                # Find the index of this emotion in the common space
                common_idx = common_emotions.index(common_emotion)
                # Add the probability
                text_probs_mapped[common_idx] += self.text_pred_probs[i]
            
            # Normalize text probabilities
            text_probs_mapped = text_probs_mapped / np.sum(text_probs_mapped) if np.sum(text_probs_mapped) > 0 else text_probs_mapped
            
            # Weighted average of all modalities
            weighted_probs = (
                weights['face'] * face_probs + 
                weights['audio'] * audio_probs + 
                weights['text'] * text_probs_mapped
            )
            
            # Get the dominant emotion
            dominant_idx = np.argmax(weighted_probs)
            dominant_emotion = common_emotions[dominant_idx]
            confidence = weighted_probs[dominant_idx]
            
            # Set UI elements
            icon = EMOTION_ICONS.get(dominant_emotion, EMOTION_ICONS['default'])
            self.aggregate_icon.set(icon)
            self.aggregate_label.set(f"{dominant_emotion.title()} (Confidence: {confidence:.1%})")

            # Show more detailed results
            detailed_result = (
                f"Combined Emotion: {dominant_emotion.title()} {icon}\n"
                f"Overall Confidence: {confidence:.1%}\n\n"
                f"Face Contribution: {weights['face']*100:.0f}%\n"
                f"Audio Contribution: {weights['audio']*100:.0f}%\n"
                f"Text Contribution: {weights['text']*100:.0f}%"
            )
            
            messagebox.showinfo("Aggregate Emotion Analysis", detailed_result)

        except Exception as e:
            messagebox.showerror("Error", f"Failed to calculate aggregate emotion: {str(e)}")

    # def calculate_aggregate(self):
    #     if None in (self.face_pred_probs, self.audio_pred_probs, self.text_pred_probs):
    #         messagebox.showinfo("Missing Data", "Please complete all three emotion predictions first.")
    #         return

    #     try:
    #         mapped_text_probs = np.zeros(len(FACE_LABELS))
    #         text_probs = self.text_pred_probs

    #         mapping = {
    #             0: 0,   # anger → angry
    #             1: 3,   # joy → happy
    #             2: 5,   # sadness → sad
    #             3: 2,   # fear → fear
    #             4: 4,   # love → neutral
    #             5: 6    # surprise → surprise
    #         }

    #         for text_idx, face_idx in mapping.items():
    #             mapped_text_probs[face_idx] += text_probs[text_idx]

    #         avg_probs = (self.face_pred_probs + self.audio_pred_probs + mapped_text_probs) / 3
    #         dominant_idx = np.argmax(avg_probs)
    #         dominant_emotion = FACE_LABELS[dominant_idx]

    #         icon = EMOTION_ICONS.get(dominant_emotion, EMOTION_ICONS['default'])
    #         self.aggregate_icon.set(icon)
    #         self.aggregate_label.set(f"{dominant_emotion.title()} (Confidence: {avg_probs[dominant_idx]:.1%})")

    #         messagebox.showinfo(
    #             "Aggregate Emotion",
    #             f"Combined Emotion: {dominant_emotion.title()} {icon}\n"
    #             f"Confidence: {avg_probs[dominant_idx]:.1%}"
    #         )

    #     except Exception as e:
    #         messagebox.showerror("Error", f"Failed to calculate aggregate emotion: {str(e)}")

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
                    cv2.rectangle(display_frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
            rgb = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
            img = Image.fromarray(rgb).resize((400, 300))
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

    def toggle_audio_record(self):
        if self.is_recording:
            self.stop_audio_recording()
        else:
            self.start_audio_recording()

    def start_audio_recording(self):
        self.is_recording = True
        self.audio_data = []
        self.audio_record_btn.config(text="⏹️ Stop")
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
        self.audio_record_btn.config(text="🎙️ Record")
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

    def text_predict(self):
        text = self.text_input.get("1.0", tk.END).strip()
        if not text:
            messagebox.showinfo("Input Required", "Please enter some text.")
            return
        self.text_predict_btn.config(state="disabled")
        self.text_pred_label.set("Predicting...")
        self.text_pred_icon.set(EMOTION_ICONS['default'])
        threading.Thread(target=self.text_predict_thread, args=(text,)).start()

    def text_predict_thread(self, text):
        label, probs = predict_text_emotion(text)
        icon = EMOTION_ICONS.get(label, EMOTION_ICONS['default'])
        self.text_pred_label.set(label.title())
        self.text_pred_icon.set(icon)
        self.text_pred_probs = probs

        def update_bars():
            if probs is not None:
                for i, l in enumerate(TEXT_LABELS):
                    self.text_prob_bars[l]['value'] = probs[i]
            self.text_predict_btn.config(state="normal")
        self.root.after(0, update_bars)

    def on_close(self):
        if hasattr(self, 'cap') and self.cap.isOpened():
            self.cap.release()
        self.root.destroy()

if __name__ == "__main__":
    tf.config.set_visible_devices([], 'GPU')
    root = ThemedTk(theme="arc")
    style = ttk.Style(root)
    style.configure("Header.TLabel", font=("Arial", 16, "bold"))
    style.configure("Section.TLabel", font=("Arial", 14, "bold"))
    style.configure("Emotion.TLabel", font=("Arial", 20))
    style.configure("ProbBar.Horizontal.TProgressbar", thickness=20)
    app = EmotionApp(root)
    root.mainloop()