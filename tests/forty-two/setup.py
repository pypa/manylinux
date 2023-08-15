from setuptools import setup, Extension

setup(
    name="forty_two",
    version="0.1.0",
    python_requires=">=3.6",
    ext_modules=[Extension("forty_two", sources=["forty-two.c"])],
)
