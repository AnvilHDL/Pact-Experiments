import os
import matplotlib.pyplot as plt
import csv
import numpy as np
import seaborn as sns
from scipy import stats

def read_data(file_path):
    data = []
    expected_size = None
    header = []
    with open(file_path, 'r', newline='') as file:
        reader = csv.reader(file)
        for row in reader:
            # skip empty rows
            if not row:
                continue
            # first non-empty row is header; don't append it to data
            if expected_size is None:
                header = row
                expected_size = len(row)
                continue
            assert len(row) == expected_size, "Inconsistent row size detected"
            data.append(dict(zip(header, row)))
    return data

# pool_name,num_automata,individual_sizes,theoretical_state_space,actual_state_space,visited_states,product_transitions,state_space_ratio,construction_time_ms,game_time_ms,total_time_ms,result,error_msg


# interesting plots to generate:
# 1. Theoretical State Space vs Actual State Space
# 2. Theoretical State Space vs Construction Time
# 3. Actual State Space vs Emptiness Checking Time





def create_plot(data):
    
    # Extract data
    theoretical = [float(row['theoretical_state_space']) for row in data]
    actual = [float(row['actual_state_space']) for row in data]
    construction_time = [float(row['construction_time_ms']) for row in data]
    game_time = [float(row['game_time_ms']) for row in data]
    efficiency = [float(row['state_space_ratio']) for row in data]
    
    # Filter out zero values for log plots
    valid_indices1 = [i for i in range(len(theoretical)) if theoretical[i] > 0 and construction_time[i] > 0]
    valid_indices2 = [i for i in range(len(efficiency)) if efficiency[i] > 0]
    valid_indices3 = [i for i in range(len(actual)) if actual[i] > 0 and game_time[i] > 0]
    
    # Set up the figure
    plt.style.use('seaborn-v0_8')
    fig, (ax1, ax3) = plt.subplots(1, 2, figsize=(18, 6), dpi=300)
    
    # Plot 1: Construction Time vs Theoretical State Space
    if valid_indices1:
        x1 = [theoretical[i] for i in valid_indices1]
        y1 = [construction_time[i] for i in valid_indices1]
        
        ax1.scatter(x1, y1, alpha=0.7, s=60, color='steelblue', edgecolors='white', linewidth=1)
        ax1.set_xscale('log')
        ax1.set_yscale('log')
        ax1.set_xlabel('Theoretical State Space', fontsize=18, fontweight='bold')
        ax1.set_ylabel('Construction Time (ms)', fontsize=18, fontweight='bold')
        ax1.set_title('Construction Time vs\nTheoretical State Space', fontsize=24, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # Add trend line if enough points
        if len(x1) > 2:
            x_log = np.log10(x1)
            y_log = np.log10(y1)
            slope, intercept, r_value, _, _ = stats.linregress(x_log, y_log)
            x_trend = np.logspace(np.log10(min(x1)), np.log10(max(x1)), 100)
            y_trend = 10**(slope * np.log10(x_trend) + intercept)
            ax1.plot(x_trend, y_trend, 'r--', linewidth=2, alpha=0.8, 
                     label=f'R² = {r_value**2:.3f}')
            ax1.legend(fontsize=18)
    
    # Plot 2: State Space Efficiency
    # if valid_indices2:
    #     y2 = [efficiency[i] for i in valid_indices2]
    #     x2_pos = range(len(y2))
        
    #     ax2.bar(x2_pos, y2, alpha=0.7, color='forestgreen', edgecolor='black', linewidth=1)
    #     ax2.set_xlabel('Test Cases', fontsize=18, fontweight='bold')
    #     ax2.set_ylabel('Efficiency (Actual/Theoretical)', fontsize=18, fontweight='bold')
    #     ax2.set_title('State Space Efficiency\n(Actual/Theoretical Ratio)', fontsize=13, fontweight='bold')
    #     ax2.grid(True, alpha=0.3, axis='y')
        
    #     # Add mean line
    #     mean_eff = np.mean(y2)
    #     ax2.axhline(mean_eff, color='red', linestyle='--', linewidth=2, 
    #                 label=f'Mean: {mean_eff:.3f}')
    #     ax2.legend(fontsize=10)
    #     ax2.set_xlim(-0.5, len(y2)-0.5)
    
    # Plot 3: Emptiness Checking Time vs Actual State Space
    if valid_indices3:
        x3 = [actual[i] for i in valid_indices3]
        y3 = [game_time[i] for i in valid_indices3]
        
        ax3.scatter(x3, y3, alpha=0.7, s=60, color='darkorange', edgecolors='white', linewidth=1)
        ax3.set_xscale('log')
        ax3.set_yscale('log')
        ax3.set_xlabel('Actual State Space', fontsize=18, fontweight='bold')
        ax3.set_ylabel('Emptiness Checking Time (ms)', fontsize=18, fontweight='bold')
        ax3.set_title('Emptiness Checking Time vs\nActual State Space', fontsize=24, fontweight='bold')
        ax3.grid(True, alpha=0.3)
        
        # Add trend line if enough points
        if len(x3) > 2:
            x_log = np.log10(x3)
            y_log = np.log10(y3)
            slope, intercept, r_value, _, _ = stats.linregress(x_log, y_log)
            x_trend = np.logspace(np.log10(min(x3)), np.log10(max(x3)), 100)
            y_trend = 10**(slope * np.log10(x_trend) + intercept)
            ax3.plot(x_trend, y_trend, 'r--', linewidth=2, alpha=0.8, 
                     label=f'R² = {r_value**2:.3f}')
            ax3.legend(fontsize=18)
    
    plt.tight_layout()
    plt.savefig('runtime.pdf', dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    plt.close()
    print("  Saved: runtime.pdf")

def main():
    data_file = 'types.csv'
    data = read_data(data_file)

    print(f"Loaded {len(data)} data points from {data_file}")
    print("Generating figures...")
    create_plot(data)

    
if __name__ == '__main__':
    main()