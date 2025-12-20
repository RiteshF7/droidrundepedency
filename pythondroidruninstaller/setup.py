"""Setup script for pythondroidruninstaller package."""

from setuptools import setup, find_packages
from pathlib import Path

# Read README
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text() if readme_file.exists() else ""

setup(
    name="pythondroidruninstaller",
    version="1.0.0",
    description="Python-based droidrun installation system",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="droidrun",
    packages=find_packages(),
    python_requires=">=3.6",
    install_requires=[
        "packaging>=21.0",
    ],
    entry_points={
        "console_scripts": [
            "droidrun-phase1=pythondroidruninstaller.phase1_build_tools:main",
        ],
    },
)

