defmodule DoomElixir.EyeTracking do
  use GenServer

  @moduledoc """
  Eye Tracking avec Elixir - Plusieurs approches possibles:

  1. **Webcam + OpenCV via Port** (Python/C++)
  2. **Tobii SDK via NIF** (Native Implemented Functions)
  3. **WebRTC + JS MediaDevices API** (Browser-based)
  4. **GazePointer/PyGaze via Port**
  """

  defstruct [:gaze_position, :calibration_data, :mode, :port]

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_gaze_position do
    GenServer.call(__MODULE__, :get_gaze)
  end

  def calibrate(points) do
    GenServer.call(__MODULE__, {:calibrate, points})
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    mode = Keyword.get(opts, :mode, :webcam)

    state = %__MODULE__{
      gaze_position: {0.5, 0.5},  # Centre de l'écran par défaut
      calibration_data: nil,
      mode: mode,
      port: nil
    }

    # Démarrer le tracking selon le mode
    {:ok, start_tracking(state)}
  end

  @impl true
  def handle_call(:get_gaze, _from, state) do
    {:reply, state.gaze_position, state}
  end

  @impl true
  def handle_call({:calibrate, points}, _from, state) do
    # Calibration avec plusieurs points de référence
    calibration_data = perform_calibration(points)
    {:reply, :ok, %{state | calibration_data: calibration_data}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Recevoir les données du port Python/OpenCV
    case parse_gaze_data(data) do
      {:ok, {x, y}} ->
        {:noreply, %{state | gaze_position: {x, y}}}

      {:error, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({_port, {:exit_status, status}}, state) do
    # Le script Python s'est terminé (probablement une erreur)
    # On continue avec la position par défaut au centre
    require Logger
    Logger.warning("Eye tracking script exited with status #{status}. Using default gaze position.")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    # Ignorer les autres messages
    {:noreply, state}
  end

  # Helpers
  defp start_tracking(%{mode: :webcam} = state) do
    # Lancer un port Python avec OpenCV
    python_script = Path.join(:code.priv_dir(:doom_elixir), "eye_tracking.py")

    port = Port.open(
      {:spawn, "python3 #{python_script}"},
      [:binary, :exit_status, packet: 4]
    )

    %{state | port: port}
  end

  defp start_tracking(%{mode: :tobii} = state) do
    # Lancer le SDK Tobii via NIF
    # Nécessite tobii_stream_engine
    :ok = :tobii_nif.start()
    state
  end

  defp start_tracking(%{mode: :webeye} = state) do
    # Mode WebRTC - les données viennent du browser
    state
  end

  defp parse_gaze_data(binary_data) do
    # Parser les données du format: <<x::float-32, y::float-32>>
    case binary_data do
      <<x::float-32, y::float-32, _rest::binary>> ->
        {:ok, {x, y}}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp perform_calibration(points) do
    # Algorithme de calibration simple
    # Points = [{screen_x, screen_y, gaze_x, gaze_y}, ...]

    # Calculer une matrice de transformation
    # Pour simplifier, on utilise une transformation affine
    Enum.reduce(points, %{offset_x: 0, offset_y: 0, scale_x: 1, scale_y: 1}, fn
      {sx, sy, gx, gy}, acc ->
        %{
          offset_x: acc.offset_x + (sx - gx),
          offset_y: acc.offset_y + (sy - gy),
          scale_x: acc.scale_x,
          scale_y: acc.scale_y
        }
    end)
  end
end

defmodule DoomElixir.EyeTracking.GazeRenderer do
  @moduledoc """
  Intégration eye tracking dans le raycasting

  - Le regard déplace la caméra automatiquement
  - Foveal rendering: haute résolution au centre du regard
  - Gaze-driven interactions
  """

  def update_camera_from_gaze(scene_state) do
    {gaze_x, gaze_y} = DoomElixir.EyeTracking.get_gaze_position()

    # Convertir position du regard en rotation caméra
    # gaze_x/y sont entre 0 et 1
    # Centre = 0.5, 0.5

    player = scene_state.assigns.player

    # Rotation basée sur le regard (smooth)
    target_angle = player.angle + (gaze_x - 0.5) * 0.1

    # Vertical look (pour plus tard - 3D complet)
    # vertical_angle = (gaze_y - 0.5) * 0.5

    new_player = %{player | angle: target_angle}

    %{scene_state | assigns: Map.put(scene_state.assigns, :player, new_player)}
  end

  def render_with_foveation(graph, player, gaze_pos) do
    {gaze_x, gaze_y} = gaze_pos

    # Foveal rendering: Plus de rayons au centre du regard
    # Périphérie: Moins de rayons (économie GPU)

    # Zone fovéale (haute résolution)
    fovea_rays = cast_foveal_rays(player, gaze_x, 200)

    # Périphérie (basse résolution)
    peripheral_rays = cast_peripheral_rays(player, gaze_x, 100)

    # Combiner et render
    all_rays = fovea_rays ++ peripheral_rays

    render_rays(graph, all_rays)
  end

  defp cast_foveal_rays(player, gaze_x, num_rays) do
    # Rayons concentrés autour du regard
    gaze_angle = player.angle + (gaze_x - 0.5) * (player.fov / 2)

    for i <- 0..(num_rays - 1) do
      offset = (i / num_rays - 0.5) * 0.3  # 30% du FOV
      angle = gaze_angle + offset

      DoomElixir.Raycaster.cast_single_ray_public(
        %{player | angle: angle},
        i * (500 / num_rays)
      )
    end
  end

  defp cast_peripheral_rays(_player, _gaze_x, _num_rays) do
    # Implémentation simplifiée
    []
  end

  defp render_rays(graph, _rays) do
    # Render optimisé
    graph
  end
end

# Script Python pour eye tracking webcam
# Sauvegarder dans priv/eye_tracking.py
"""
#!/usr/bin/env python3
import cv2
import mediapipe as mp
import struct
import sys

mp_face_mesh = mp.solutions.face_mesh

def get_eye_gaze(face_landmarks, frame_width, frame_height):
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
"""
