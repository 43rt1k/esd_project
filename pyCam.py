import cv2

def list_available_cameras(max_devices=10):
    available = []
    for i in range(max_devices):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            available.append(i)
            cap.release()
    return available

def main():
    """
    print("🔍 Searching for available camera devices...")
    cameras = list_available_cameras()
    if not cameras:
        print("❌ No cameras found.")
        return

    print("🎥 Available cameras:")
    for idx in cameras:
        print(f"  [{idx}] Camera {idx}")

    while True:
        try:
            selected = int(input("Select camera index to open: "))
            if selected in cameras:
                break
            else:
                print("Invalid selection. Try again.")
        except ValueError:
            print("Please enter a number.")
    """
    selected = 0
    cap = cv2.VideoCapture(selected)
    if not cap.isOpened():
        print("❌ Failed to open the selected camera.")
        return

    print("📷 Press 'q' to quit the camera window.")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("⚠️ Failed to grab frame.")
            break
        cv2.imshow(f"Camera {selected}", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()