{
  description = "ExLlamaV2 - Inference library for running local LLMs on modern consumer GPUs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };

        # Override python packages to disable tests that require network access
        pythonPackages = pkgs.python311Packages.override {
          overrides = self: super: {
            websockets = super.websockets.overridePythonAttrs (old: {
              doCheck = false;
            });
          };
        };

        exllamav2 = pythonPackages.buildPythonPackage rec {
          pname = "exllamav2";
          version = "0.1.0";
          format = "setuptools";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            cudaPackages.cuda_nvcc
            cudaPackages.cuda_cudart
            ninja
          ] ++ (with pythonPackages; [
            setuptools
            wheel
          ]);

          buildInputs = with pkgs; [
            cudaPackages.cuda_cudart
            cudaPackages.libcublas
            cudaPackages.libcusparse
            cudaPackages.libcusolver
          ];

          propagatedBuildInputs = with pythonPackages; [
            pandas
            ninja
            wheel
            setuptools
            fastparquet
            torch-bin
            safetensors
            pygments
            websockets
            regex
            numpy
            tokenizers
            rich
            pillow
          ];

          # Skip tests during build
          doCheck = false;

          # Set environment variables for CUDA compilation
          preBuild = ''
            export CUDA_HOME="${pkgs.cudaPackages.cuda_nvcc}"
            export TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0"
          '';

          meta = with pkgs.lib; {
            description = "Inference library for running local LLMs on modern consumer GPUs";
            homepage = "https://github.com/turboderp/exllamav2";
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };

      in
      {
        packages = {
          default = exllamav2;
          exllamav2 = exllamav2;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            (pythonPackages.python.withPackages (ps: with ps; [
              pandas
              ninja
              wheel
              setuptools
              fastparquet
              torch-bin
              safetensors
              pygments
              websockets
              regex
              numpy
              tokenizers
              rich
              pillow
            ]))
            pkgs.cudaPackages.cuda_nvcc
            pkgs.cudaPackages.cuda_cudart
            pkgs.cudaPackages.libcublas
            pkgs.cudaPackages.libcusparse
            pkgs.cudaPackages.libcusolver
            pkgs.ninja
            pkgs.git
          ];

          shellHook = ''
            export CUDA_HOME="${pkgs.cudaPackages.cuda_nvcc}"
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
              pkgs.cudaPackages.cuda_cudart
              pkgs.cudaPackages.libcublas
              pkgs.cudaPackages.libcusparse
              pkgs.cudaPackages.libcusolver
              pkgs.stdenv.cc.cc.lib
            ]}:$LD_LIBRARY_PATH"
            export TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9;9.0"

            echo "ExLlamaV2 development environment"
            echo "To install in development mode: pip install -e ."
            echo "To run tests: python test_inference.py -m <path_to_model> -p 'Once upon a time,'"
          '';
        };
      }
    );
}
