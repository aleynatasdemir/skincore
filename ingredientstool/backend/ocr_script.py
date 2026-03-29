import os
import sys
import logging
import warnings

# Suppress warnings and logs
os.environ["KMP_WARNINGS"] = "0"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
warnings.filterwarnings('ignore')
logging.getLogger('ppocr').setLevel(logging.ERROR)

from paddleocr import PaddleOCR

def process_image(image_path):
    try:
        # Initialize PaddleOCR
        ocr = PaddleOCR(use_angle_cls=True, lang="en")
        result = ocr.ocr(image_path)
        
        extracted_text = []
        if result and result[0]:
            for line in result[0]:
                extracted_text.append(line[1][0])
                
        # We join by space or newline depending on requirement
        res = " ".join(extracted_text)
        print(f"!!!OCR_RESULT_START!!!{res}!!!OCR_RESULT_END!!!")
    except Exception as e:
        print(f"OCR Error: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        process_image(sys.argv[1])
    else:
        print("Error: No image path provided", file=sys.stderr)
