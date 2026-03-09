import sys

def parse_lcov(file_path):
    coverage = {}
    current_file = None
    lines_found = 0
    lines_hit = 0
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('SF:'):
                current_file = line[3:]
                lines_found = 0
                lines_hit = 0
            elif line.startswith('LF:'):
                lines_found = int(line[3:])
            elif line.startswith('LH:'):
                lines_hit = int(line[3:])
            elif line == 'end_of_record':
                if current_file and lines_found > 0:
                    # Filter out generated files
                    if ('.g.dart' not in current_file and 
                        '.freezed.dart' not in current_file and 
                        'generated_plugin_registrant.dart' not in current_file and 
                        '/generated/' not in current_file and 
                        '/previews/' not in current_file):
                        
                        cov_pct = (lines_hit / lines_found) * 100
                        coverage[current_file] = {
                            'pct': cov_pct,
                            'hit': lines_hit,
                            'found': lines_found,
                            'missed': lines_found - lines_hit
                        }
    return coverage

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python parse_lcov.py <lcov.info>")
        sys.exit(1)
    
    cov = parse_lcov(sys.argv[1])
    sorted_cov = sorted(cov.items(), key=lambda x: x[1]['pct'])
    
    total_found = sum(x['found'] for x in cov.values())
    total_hit = sum(x['hit'] for x in cov.values())
    total_pct = (total_hit / total_found * 100) if total_found > 0 else 0
    
    print(f"Total Coverage: {total_pct:.2f}%")
    print("\nFiles with missing coverage (sorted by lowest %):")
    for file, data in sorted_cov:
        if data['pct'] < 100:
            print(f"{data['pct']:05.2f}% ({data['hit']}/{data['found']}): {file}")
