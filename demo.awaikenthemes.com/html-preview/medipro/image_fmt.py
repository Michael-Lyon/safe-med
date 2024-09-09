from PIL import Image

# Load the generated image
image_path = "images/logo.webp"
image = Image.open(image_path)

# Resize to the first dimension 165 x 64
image_resized_165_64 = image.resize((165, 64))
image_resized_165_64_path = "images/logo_165.webp"
image_resized_165_64.save(image_resized_165_64_path)

# Resize to the second dimension 140 x 54.3 (rounded to nearest integer)
image_resized_140_54 = image.resize((140, 54))
image_resized_140_54_path = "images/logo_140.webp"
image_resized_140_54.save(image_resized_140_54_path)

(image_resized_165_64_path, image_resized_140_54_path)
