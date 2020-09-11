from setuptools import setup

long_description = open('README.md').read()

setup(
    name="xontrib-xlsd",
    version="0.0.5",
    license="GPLv3",
    url="https://github.com/cafehaine/xontrib-xlsd",
    description="An improved ls for xonsh, inspired by lsd",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="CaféHaine",
    author_email="kilian.guillaume@gmail.com",
    packages=['xontrib', 'xlsd'],
    package_dir={'xontrib': 'xontrib', 'xlsd': 'xlsd'},
    package_data={'xontrib': ['*.xsh'], 'xlsd': ['*.py']},
    zip_safe=False,
    classifiers=[
        "Environment :: Console",
        "Environment :: Plugins",
        "License :: OSI Approved :: GNU General Public License v3 (GPLv3)",
        "Operating System :: POSIX",
        "Programming Language :: Python :: 3"
    ]
)
