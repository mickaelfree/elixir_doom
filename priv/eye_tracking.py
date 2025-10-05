#!/usr/bin/env python3
import cv2
import mediapipe as mp
import struct
import sys

mp_face_mesh = mp.solutions.face_mesh

def get_eye_gaze(face_landmarks, frame_width, frame_height):
    """
    Extract gaze position from face landmarks.
    Uses eye corner landmarks to estimate gaze direction.
    """
    # Landmarks des yeux
    left_eye = face_landmarks.landmark[33]  # Coin de l'oeil gauche
    right_eye = face_landmarks.landmark[263]  # Coin de l'oeil droit

    # Position moyenne
    x = (left_eye.x + right_eye.x) / 2
    y = (left_eye.y + right_eye.y) / 2

    return x, y

def main():
    cap = cv2.VideoCapture(0)

    with mp_face_mesh.FaceMesh(
        max_num_faces=1,
        refine_landmarks=True,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    ) as face_mesh:

        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                continue

            frame.flags.writeable = False
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = face_mesh.process(frame)

            if results.multi_face_landmarks:
                for face_landmarks in results.multi_face_landmarks:
                    x, y = get_eye_gaze(
                        face_landmarks,
                        frame.shape[1],
                        frame.shape[0]
                    )

                    # Envoyer au port Elixir (format: length prefix + data)
                    data = struct.pack('ff', x, y)
                    length = struct.pack('!I', len(data))
                    sys.stdout.buffer.write(length + data)
                    sys.stdout.buffer.flush()

    cap.release()

if __name__ == "__main__":
    main()
