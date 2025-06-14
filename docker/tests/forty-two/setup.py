from setuptools import Extension, setup

setup(
    name="forty_two",
    version="0.1.0",
    python_requires=">=3.8",
    ext_modules=[Extension("forty_two", sources=["forty-two.c"])],
)
