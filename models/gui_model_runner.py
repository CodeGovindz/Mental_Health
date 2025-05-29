import tkinter as tk
from tkinter import ttk
import cv2
import os
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

# --- Model Paths ---
BASE_DIR = os.path.dirname(__file__)
FACE_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'emotion_recognition_model_100.h5')
AUDIO_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'Speech Emotion Recognition Minor Project', 'LSTM Model', 'speech_emotion_recognition_model_lstm.h5')
SCALER_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'Speech Emotion Recognition Minor Project', 'LSTM Model', 'scalerLSTM.pkl')
TEXT_MODEL_PATH = os.path.join(BASE_DIR, 'ML', 'models', 'emotion-distilbert-model')

# --- Constants ---
FACE_IMG_SIZE = (48, 48)
FACE_LABELS = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']
AUDIO_LABELS = ['angry', 'disgust', 'fear', 'happy', 'neutral', 'sad', 'surprise']
AUDIO_DURATION = 4  # seconds
AUDIO_SR = 16000
TEXT_LABELS = ['anger', 'joy', 'sadness', 'fear', 'love', 'surprise']

# --- Load Models ---
try:
    face_model = tf.keras.models.load_model(FACE_MODEL_PATH)
    print("Face model loaded successfully.")
except Exception as e:
    face_model = None
    print(f"Error loading face model: {e}")

try:
    with open(SCALER_PATH, 'rb') as f:
        audio_scaler = pickle.load(f)
    audio_model = tf.keras.models.load_model(AUDIO_MODEL_PATH)
    print("Audio model and scaler loaded successfully.")
except Exception as e:
    audio_model = None
    audio_scaler = None
    print(f"Error loading audio model/scaler: {e}")

try:
    text_tokenizer = DistilBertTokenizerFast.from_pretrained(TEXT_MODEL_PATH)
    text_model = DistilBertForSequenceClassification.from_pretrained(TEXT_MODEL_PATH)
    text_model.eval() # Set model to evaluation mode
    print("Text model and tokenizer loaded successfully.")
except Exception as e:
    text_model = None
    text_tokenizer = None
    print(f"Error loading text model/tokenizer: {e}")

# --- Prediction Functions (adapted for GUI) ---
def predict_face_emotion(img_array):
    if face_model is None: return "Error: Face model not loaded."
    img = img_array.astype('float32') / 255.0
    img = np.expand_dims(img, axis=(0, -1))  # (1, 48, 48, 1)
    try:
        preds = face_model.predict(img, verbose=0)
        label = FACE_LABELS[np.argmax(preds)]
        return label
    except Exception as e:
        print(f"Error predicting face emotion: {e}")
        return "Error predicting."

def extract_audio_features(y, sr):
    # Feature extraction as in TesterLSTM.py
    zcr = np.mean(librosa.feature.zero_crossing_rate(y=y).T, axis=0)
    stft = np.abs(librosa.stft(y))
    chroma_stft = np.mean(librosa.feature.chroma_stft(S=stft, sr=sr).T, axis=0)
    mfcc = np.mean(librosa.feature.mfcc(y=y, sr=sr).T, axis=0)
    rms = np.mean(librosa.feature.rms(y=y).T, axis=0)
    mel = np.mean(librosa.feature.melspectrogram(y=y, sr=sr).T, axis=0)
    features = np.hstack((zcr, chroma_stft, mfcc, rms, mel))
    return features

def predict_audio_emotion(file_path):
    if audio_model is None or audio_scaler is None: return "Error: Audio model/scaler not loaded."
    try:
        y, sr = librosa.load(file_path, sr=AUDIO_SR)
        features = extract_audio_features(y, sr)
        features_scaled = audio_scaler.transform(features.reshape(1, -1))
        features_reshaped = np.expand_dims(features_scaled, axis=2)
        preds = audio_model.predict(features_reshaped, verbose=0)
        label = AUDIO_LABELS[np.argmax(preds)]
        os.remove(file_path) # Clean up temp file
        return label
    except Exception as e:
        print(f"Error predicting audio emotion: {e}")
        if os.path.exists(file_path): os.remove(file_path)
        return "Error predicting."

def predict_text_emotion(text):
    if text_model is None or text_tokenizer is None: return "Error: Text model/tokenizer not loaded."
    try:
        inputs = text_tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=128)
        with torch.no_grad():
            outputs = text_model(**inputs)
        logits = outputs.logits
        pred = torch.argmax(logits, dim=1).item()
        return TEXT_LABELS[pred]
    except Exception as e:
        print(f"Error predicting text emotion: {e}")
        return "Error predicting."

# --- GUI Application ---
class EmotionApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Multimodal Emotion Runner")

        # --- Layout ---
        self.main_frame = ttk.Frame(root, padding="10")
        self.main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)

        self.left_frame = ttk.Frame(self.main_frame, padding="5")
        self.left_frame.grid(row=0, column=0, sticky=(tk.N, tk.S, tk.E, tk.W))
        self.main_frame.columnconfigure(0, weight=1)
        self.main_frame.rowconfigure(0, weight=1)

        self.right_frame = ttk.Frame(self.main_frame, padding="5")
        self.right_frame.grid(row=0, column=1, sticky=(tk.N, tk.S, tk.E, tk.W))
        self.main_frame.columnconfigure(1, weight=1)

        # --- Left Side (Camera & Face Emotion) ---
        self.camera_label = ttk.Label(self.left_frame)
        self.camera_label.grid(row=0, column=0, sticky=(tk.N, tk.W, tk.E, tk.S))
        self.left_frame.columnconfigure(0, weight=1)
        self.left_frame.rowconfigure(0, weight=1)

        self.face_emotion_label = ttk.Label(self.left_frame, text="Face Emotion:")
        self.face_emotion_label.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=5)

        self.cap = cv2.VideoCapture(0) # Initialize webcam
        self.photo = None
        self.update_camera()

        # --- Right Side (Text & Audio Emotion) ---
        self.text_frame = ttk.LabelFrame(self.right_frame, text="Text Emotion", padding="10")
        self.text_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N), pady=5)
        self.right_frame.columnconfigure(0, weight=1)

        self.text_input = tk.Text(self.text_frame, height=4, width=40)
        self.text_input.grid(row=0, column=0, sticky=(tk.W, tk.E))
        self.text_frame.columnconfigure(0, weight=1)

        self.text_predict_button = ttk.Button(self.text_frame, text="Predict Text Emotion", command=self.run_text_prediction)
        self.text_predict_button.grid(row=1, column=0, pady=5)

        self.text_emotion_label = ttk.Label(self.text_frame, text="Predicted Text Emotion:")
        self.text_emotion_label.grid(row=2, column=0, sticky=(tk.W, tk.E))

        self.audio_frame = ttk.LabelFrame(self.right_frame, text="Audio Emotion", padding="10")
        self.audio_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N), pady=5)

        self.audio_record_button = ttk.Button(self.audio_frame, text="Record Audio", command=self.start_audio_recording)
        self.audio_record_button.grid(row=0, column=0, pady=5)
        self.audio_frame.columnconfigure(0, weight=1)

        self.audio_status_label = ttk.Label(self.audio_frame, text="Status: Ready")
        self.audio_status_label.grid(row=1, column=0, sticky=(tk.W, tk.E))

        self.audio_emotion_label = ttk.Label(self.audio_frame, text="Predicted Audio Emotion:")
        self.audio_emotion_label.grid(row=2, column=0, sticky=(tk.W, tk.E))

        self.is_recording = False
        self.audio_data = []
        self.audio_stream = None

        # --- Mental Health Questions (for audio) ---
        self.audio_questions = [
            "How are you feeling right now?",
            "Can you describe your mood today?",
            "What has been on your mind lately?"
        ]
        self.current_audio_question = ""

    def update_camera(self):
        ret, frame = self.cap.read()
        if ret:
            # Convert frame to grayscale for face detection/prediction
            gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) # Convert for display

            # Perform face emotion prediction every 2 seconds
            if int(time.time() * 10) % 20 == 0: # Roughly every 2 seconds
                 face_img = cv2.resize(gray_frame, FACE_IMG_SIZE)
                 # Run prediction in a separate thread to keep GUI responsive
                 threading.Thread(target=self.run_face_prediction_thread, args=(face_img,)).start()

            img = Image.fromarray(rgb_frame)
            self.photo = ImageTk.PhotoImage(image=img)
            self.camera_label.config(image=self.photo)

        self.root.after(10, self.update_camera) # Update every 10ms

    def run_face_prediction_thread(self, face_img):
         predicted_emotion = predict_face_emotion(face_img)
         # Update GUI from the main thread
         self.root.after(0, lambda: self.face_emotion_label.config(text=f"Face Emotion: {predicted_emotion}"))

    def run_text_prediction(self):
        text = self.text_input.get("1.0", tk.END).strip()
        if text:
            predicted_emotion = predict_text_emotion(text)
            self.text_emotion_label.config(text=f"Predicted Text Emotion: {predicted_emotion}")
        else:
            self.text_emotion_label.config(text="Predicted Text Emotion: (Enter text)")

    def start_audio_recording(self):
        if self.is_recording:
            self.stop_audio_recording()
        else:
            self.is_recording = True
            self.audio_data = []
            self.audio_record_button.config(text="Stop Recording")
            self.audio_status_label.config(text="Status: Recording...")
            self.current_audio_question = np.random.choice(self.audio_questions)
            print(f"\nAudio Question: {self.current_audio_question}") # Print question to console

            def callback(indata, frames, time, status):
                if status:
                    print(status)
                self.audio_data.append(indata.copy())

            self.audio_stream = sd.InputStream(
                samplerate=AUDIO_SR,
                channels=1,
                dtype='float32',
                callback=callback
            )
            self.audio_stream.start()
            # Stop recording after duration in a separate thread
            threading.Timer(AUDIO_DURATION, self.stop_audio_recording_thread).start()

    def stop_audio_recording_thread(self):
        # Stop the stream from a different thread
        if self.is_recording:
             self.root.after(0, self.stop_audio_recording) # Call the main thread stop function

    def stop_audio_recording(self):
        if self.is_recording:
            self.is_recording = False
            self.audio_record_button.config(text="Record Audio")
            self.audio_status_label.config(text="Status: Processing...")

            if self.audio_stream:
                self.audio_stream.stop()
                self.audio_stream.close()
                print("Recording stopped.")

            if self.audio_data:
                recorded_audio = np.concatenate(self.audio_data, axis=0)
                temp_file = "temp_recorded_audio.wav"
                sf.write(temp_file, recorded_audio, AUDIO_SR)
                print(f"Saved temporary audio to {temp_file}")

                # Run audio prediction in a separate thread
                threading.Thread(target=self.run_audio_prediction_thread, args=(temp_file,)).start()
            else:
                 self.audio_status_label.config(text="Status: No audio recorded.")

    def run_audio_prediction_thread(self, temp_file):
        predicted_emotion = predict_audio_emotion(temp_file)
        # Update GUI from the main thread
        self.root.after(0, lambda: [
            self.audio_emotion_label.config(text=f"Predicted Audio Emotion: {predicted_emotion}"),
            self.audio_status_label.config(text="Status: Ready")
        ])


    def __del__(self):
        if self.cap and self.cap.isOpened():
            self.cap.release()

if __name__ == "__main__":
    # Force CPU usage for TensorFlow to avoid GPU conflicts with other libraries
    tf.config.set_visible_devices([], 'GPU')

    root = tk.Tk()
    app = EmotionApp(root)
    root.mainloop() 

# import tkinter as tk
# from tkinter import ttk, messagebox
# from ttkthemes import ThemedTk
# import cv2
# import os
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
# import datetime
# import json
# from collections import deque
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

# # --- Load Models ---
# try:
#     face_model = tf.keras.models.load_model(FACE_MODEL_PATH)
# except:
#     face_model = None

# try:
#     with open(SCALER_PATH, 'rb') as f:
#         audio_scaler = pickle.load(f)
#     audio_model = tf.keras.models.load_model(AUDIO_MODEL_PATH)
# except:
#     audio_model = None
#     audio_scaler = None

# try:
#     text_tokenizer = DistilBertTokenizerFast.from_pretrained(TEXT_MODEL_PATH)
#     text_model = DistilBertForSequenceClassification.from_pretrained(TEXT_MODEL_PATH)
#     text_model.eval()
# except:
#     text_tokenizer = None
#     text_model = None

# # --- Utility Functions ---
# def detect_face(frame):
#     face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
#     gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
#     faces = face_cascade.detectMultiScale(gray, 1.1, 4)
#     if len(faces) > 0:
#         x, y, w, h = max(faces, key=lambda rect: rect[2]*rect[3])
#         return gray[y:y+h, x:x+w]
#     return None

# def predict_face_emotion(img_array):
#     if face_model is None:
#         return "Model not loaded"
#     img = img_array.astype('float32') / 255.0
#     img = np.expand_dims(img, axis=(0, -1))
#     preds = face_model.predict(img, verbose=0)
#     label = FACE_LABELS[np.argmax(preds)]
#     return label

# def predict_audio_emotion(file_path):
#     if audio_model is None or audio_scaler is None:
#         return "Model not loaded"
#     y, sr = librosa.load(file_path, sr=AUDIO_SR)
#     features = extract_audio_features(y, sr)
#     features_scaled = audio_scaler.transform(features.reshape(1, -1))
#     features_reshaped = np.expand_dims(features_scaled, axis=2)
#     preds = audio_model.predict(features_reshaped, verbose=0)
#     os.remove(file_path)
#     return AUDIO_LABELS[np.argmax(preds)]

# def extract_audio_features(y, sr):
#     zcr = np.mean(librosa.feature.zero_crossing_rate(y=y).T, axis=0)
#     stft = np.abs(librosa.stft(y))
#     chroma_stft = np.mean(librosa.feature.chroma_stft(S=stft, sr=sr).T, axis=0)
#     mfcc = np.mean(librosa.feature.mfcc(y=y, sr=sr).T, axis=0)
#     rms = np.mean(librosa.feature.rms(y=y).T, axis=0)
#     mel = np.mean(librosa.feature.melspectrogram(y=y, sr=sr).T, axis=0)
#     return np.hstack((zcr, chroma_stft, mfcc, rms, mel))

# def predict_text_emotion(text):
#     if text_model is None or text_tokenizer is None:
#         return "Model not loaded"
#     inputs = text_tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=128)
#     with torch.no_grad():
#         outputs = text_model(**inputs)
#     pred = torch.argmax(outputs.logits, dim=1).item()
#     return TEXT_LABELS[pred]

# def transcribe_audio(file_path):
#     try:
#         recognizer = sr.Recognizer()
#         with sr.AudioFile(file_path) as source:
#             audio_data = recognizer.record(source)
#             return recognizer.recognize_google(audio_data)
#     except:
#         return ""

# class EmotionApp:
#     def __init__(self, root):
#         self.root = root
#         self.root.title("Multimodal Emotion Dashboard")

#         self.emotion_bars = {}
#         self.last_predicted_emotion = None
#         self.face_history = deque(maxlen=100)

#         self.left_frame = ttk.Frame(root)
#         self.left_frame.grid(row=0, column=0, rowspan=2, sticky="nsew", padx=10, pady=10)
#         self.right_frame = ttk.Frame(root)
#         self.right_frame.grid(row=0, column=1, sticky="nsew", padx=10, pady=10)
#         self.bottom_right_frame = ttk.Frame(root)
#         self.bottom_right_frame.grid(row=1, column=1, sticky="nsew", padx=10, pady=10)

#         root.columnconfigure(0, weight=2)
#         root.columnconfigure(1, weight=1)
#         root.rowconfigure(0, weight=3)
#         root.rowconfigure(1, weight=2)

#         # --- Left: Camera and emotion bars ---
#         self.camera_label = ttk.Label(self.left_frame)
#         self.camera_label.pack()

#         for emotion in FACE_LABELS:
#             bar = ttk.Progressbar(self.left_frame, length=150, mode='determinate', maximum=100)
#             bar.pack(pady=2)
#             self.emotion_bars[emotion] = bar

#         # --- Top Right: Text Question ---
#         self.question_label = ttk.Label(self.right_frame, text="How have you been feeling emotionally this week?", wraplength=300)
#         self.question_label.pack(pady=5)

#         self.text_input = tk.Text(self.right_frame, height=5)
#         self.text_input.pack()
#         self.text_submit = ttk.Button(self.right_frame, text="Analyze Text", command=self.run_text)
#         self.text_submit.pack()
#         self.text_result = ttk.Label(self.right_frame, text="")
#         self.text_result.pack()

#         # --- Bottom Right: Audio Question ---
#         self.audio_question_label = ttk.Label(self.bottom_right_frame, text="Speak briefly: What is affecting your mood today?", wraplength=300)
#         self.audio_question_label.pack(pady=5)
#         self.record_button = ttk.Button(self.bottom_right_frame, text="Record Answer", command=self.record_audio)
#         self.record_button.pack()
#         self.audio_result = ttk.Label(self.bottom_right_frame, text="")
#         self.audio_result.pack()
#         self.audio_transcript = ttk.Label(self.bottom_right_frame, text="", wraplength=300)
#         self.audio_transcript.pack()

#         self.cap = cv2.VideoCapture(0)
#         self.update_camera()

#     def update_camera(self):
#         ret, frame = self.cap.read()
#         if ret:
#             face = detect_face(frame)
#             if face is not None and int(time.time()) % 2 == 0:
#                 face_resized = cv2.resize(face, FACE_IMG_SIZE)
#                 threading.Thread(target=self.update_emotion_bars, args=(face_resized,)).start()
#             rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
#             img = Image.fromarray(rgb)
#             photo = ImageTk.PhotoImage(image=img)
#             self.camera_label.config(image=photo)
#             self.camera_label.image = photo
#         self.root.after(100, self.update_camera)

#     def update_emotion_bars(self, face_img):
#         emotion = predict_face_emotion(face_img)
#         self.last_predicted_emotion = emotion
#         for em, bar in self.emotion_bars.items():
#             bar['value'] = 100 if em == emotion else 0

#     def run_text(self):
#         text = self.text_input.get("1.0", tk.END).strip()
#         if text:
#             emotion = predict_text_emotion(text)
#             self.text_result.config(text=f"Text Emotion: {emotion} {EMOTION_ICONS.get(emotion, '')}")

#     def record_audio(self):
#         threading.Thread(target=self._record_audio_thread).start()

#     def _record_audio_thread(self):
#         filename = "temp_audio.wav"
#         self.root.after(0, lambda: self.record_button.config(text="Recording..."))

#         try:
#             audio = sd.rec(int(AUDIO_DURATION * AUDIO_SR), samplerate=AUDIO_SR, channels=1, dtype='float32')
#             sd.wait()
#             sf.write(filename, audio, AUDIO_SR)

#             emotion = predict_audio_emotion(filename)
#             transcript = transcribe_audio(filename)

#             self.root.after(0, lambda: self.audio_result.config(
#                 text=f"Audio Emotion: {emotion} {EMOTION_ICONS.get(emotion, '')}"))
#             self.root.after(0, lambda: self.audio_transcript.config(
#                 text=f"Transcript: {transcript}"))

#         except Exception as e:
#             self.root.after(0, lambda: self.audio_result.config(text=f"Error: {e}"))

#         self.root.after(0, lambda: self.record_button.config(text="Record Answer"))


# if __name__ == '__main__':
#     tf.config.set_visible_devices([], 'GPU')
#     root = ThemedTk(theme="arc")
#     app = EmotionApp(root)
#     root.mainloop()
