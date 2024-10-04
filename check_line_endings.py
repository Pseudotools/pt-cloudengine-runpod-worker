import os

def check_line_endings(directory):
    # List to store files with wrong line endings
    wrong_line_ending_files = []
    
    # Walk through the directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                # Open the file in read mode
                with open(file_path, 'rb') as f:  # Open as binary to avoid decoding issues
                    content = f.read()
                    
                    # Check for CRLF line endings
                    if b'\r\n' in content:
                        wrong_line_ending_files.append(file_path)
            except Exception as e:
                print(f"Error reading file {file_path}: {e}")
    
    # Print the files with wrong line endings
    if wrong_line_ending_files:
        print("Files with Windows-style line endings (CRLF):")
        for wrong_file in wrong_line_ending_files:
            print(wrong_file)
    else:
        print("No files with Windows-style line endings found.")

# Get directory path from user
if __name__ == "__main__":
    #directory_path = input("Enter the directory path to check for wrong line endings: ")
    directory_path = r"Y:\GitHub\runpod-worker-comfy"
    check_line_endings(directory_path)
