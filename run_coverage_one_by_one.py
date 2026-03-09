import subprocess
import os
import glob
import sys
import shutil

def main():
    os.chdir('/Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta/origna_gta')
    
    test_files = glob.glob('test/**/*_test.dart', recursive=True)
    
    print(f"Found {len(test_files)} test files.")
    
    os.makedirs('tmp_coverage', exist_ok=True)
    if os.path.exists('coverage'):
        shutil.rmtree('coverage')
    os.makedirs('coverage', exist_ok=True)
    
    failures = []
    timeouts = []
    
    for i, file in enumerate(test_files):
        print(f"[{i+1}/{len(test_files)}] Running {file}...", flush=True)
        try:
            # Run flutter test --coverage
            result = subprocess.run(
                ['flutter', 'test', '--coverage', file],
                timeout=90,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            
            if result.returncode == 0:
                print(f"  ✅ Passed", flush=True)
                if os.path.exists('coverage/lcov.info'):
                    shutil.copy('coverage/lcov.info', f'tmp_coverage/lcov_{i}.info')
            else:
                print(f"  ❌ Failed (Exit code {result.returncode})", flush=True)
                failures.append(file)
        except subprocess.TimeoutExpired:
            print(f"  ⏳ Timed out!", flush=True)
            timeouts.append(file)
            
    print("\n--- Summary ---", flush=True)
    if timeouts:
        print("Timed out tests:")
        for t in timeouts:
            print(f"  {t}")
            
    if failures:
        print("Failed tests:")
        for f in failures:
            print(f"  {f}")
            
    print("\nMerging coverage...", flush=True)
    lcov_files = glob.glob('tmp_coverage/lcov_*.info')
    if lcov_files:
        lcov_cmd = ['lcov']
        for lf in lcov_files:
            lcov_cmd.extend(['-a', lf])
        lcov_cmd.extend(['-o', 'coverage/lcov_merged.info'])
        
        try:
            subprocess.run(lcov_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            
            # Filter
            subprocess.run([
                'lcov', '--ignore-errors', 'unused', '--remove', 'coverage/lcov_merged.info',
                'lib/**/*.g.dart', 'lib/**/*.freezed.dart', 'lib/**/generated_plugin_registrant.dart', 'lib/generated/**',
                '-o', 'coverage/lcov.info'
            ], check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            
            print("✅ Merged and filtered lcov.info", flush=True)
            
            # Print coverage percentage
            res = subprocess.run(['lcov', '--summary', 'coverage/lcov.info'], capture_output=True, text=True)
            print(res.stdout, flush=True)
            
        except subprocess.CalledProcessError as e:
            print(f"Error merging coverage: {e}", flush=True)
            
if __name__ == '__main__':
    main()
