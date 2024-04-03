#!/bin/bash

# Exit in case of error
set -e

# Step 1: Creating Distribution Packages
echo "Creating distribution packages..."
python setup.py sdist bdist_wheel

# Step 2: Installing Twine (if not already installed)
if ! command -v twine &> /dev/null
then
    echo "Twine not found, installing Twine..."
    pip install twine
fi

# Step 3: Uploading to TestPyPI (optional)
echo "Do you want to upload to TestPyPI first? (y/n)"
read upload_test
if [ "$upload_test" = "y" ]; then
    echo "Uploading to TestPyPI..."
    twine upload --repository-url https://test.pypi.org/legacy/ dist/*
    echo "You can now test install your package using TestPyPI."
fi

# Step 4: Uploading to PyPI
echo "Ready to upload to PyPI. Proceed? (y/n)"
read upload_pypi
if [ "$upload_pypi" = "y" ]; then
    echo "Uploading to PyPI..."
    twine upload dist/*
    echo "Package uploaded to PyPI."
else
    echo "Upload to PyPI aborted."
fi

echo "Script completed."
