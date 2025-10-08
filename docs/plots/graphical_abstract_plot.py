import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

df = pd.read_csv('../data-for-plots/ml_models_performance_results.csv')

# Clean up architecture names for plot
arch_map = {
    'VM': 'VM',
    'ECS_Private_IP': 'ECS 1-task (Priv IP)',
    'ECS_Public_IP': 'ECS 1-task (Pub IP)',
    'ECS_3Task_LoadBalanced': 'ECS 3-task LB'
}
df['Arch'] = df['Deployment_Architecture'].map(arch_map)

# Create Graphical Abstract version
def create_graphical_abstract():
    # Set figure size for GA: 660x295 pixels at 100 DPI
    fig, ax = plt.subplots(figsize=(6.6, 2.95), dpi=100)
    
    # Filter to Python 3.12 only for cleaner visualization
    df_filtered = df[df['Python_Version'] == 3.12].copy()
    
    # Create model categories for better organization
    model_order = ['Logistic_Regression', 'LightGBM', 'XGBoost', 'Stacking_Traditional', 
                   'CNN', 'LSTM', 'Transformers', 'Stacking_DL']
    model_labels = ['LogReg', 'LightGBM', 'XGBoost', 'Stacking-ML', 
                    'CNN', 'LSTM', 'Transformers', 'Stacking-DL']
    
    # Filter and reorder data
    df_filtered = df_filtered[df_filtered['Model_Name'].isin(model_order)]
    df_filtered['Model_Name'] = pd.Categorical(df_filtered['Model_Name'], categories=model_order, ordered=True)
    df_filtered = df_filtered.sort_values('Model_Name')
    
    # Create color palette: cooler colors for traditional ML, warmer for DL
    colors = ['#2E86AB', '#A23B72', '#F18F01', '#C73E1D']  # Blue, Purple, Orange, Red
    
    # Create the bar plot
    sns.barplot(
        data=df_filtered,
        x='Model_Name',
        y='Median_Response_Time_ms',
        hue='Arch',
        palette=colors,
        ax=ax
    )
    
    # Customize the plot for GA
    ax.set_xlabel('ML/DL Models', fontsize=10, fontweight='bold')
    ax.set_ylabel('Response Time (ms)', fontsize=10, fontweight='bold')
    ax.set_title('Real-Time Fraud Detection: ML Performance vs Deployment Architecture', 
                fontsize=11, fontweight='bold', pad=10)
    
    # Update x-axis labels - first set the tick positions, then labels
    ax.set_xticks(range(len(model_labels)))
    ax.set_xticklabels(model_labels, rotation=45, ha='right', fontsize=8)
    
    # Update y-axis
    ax.set_ylim(0, max(df_filtered['Median_Response_Time_ms']) * 1.1)
    ax.tick_params(axis='y', labelsize=8)
    
    # Customize legend
    legend = ax.legend(title='Architecture', fontsize=7, title_fontsize=8, 
                      loc='upper left', frameon=True, fancybox=True, shadow=True)
    legend.get_frame().set_alpha(0.9)
    
    # Add annotation to highlight key finding
    ax.annotate('Traditional ML models\nachieve sub-100ms latency', 
                xy=(1.5, 50), xytext=(3, 200),
                arrowprops=dict(arrowstyle='->', color='black', alpha=0.7),
                fontsize=7, ha='center', bbox=dict(boxstyle='round,pad=0.3', 
                facecolor='white', alpha=0.8))
    
    # Improve layout
    plt.tight_layout()
    
    # Save as JPG with optimization for file size (removed unsupported quality parameter)
    plt.savefig('graphical_abstract.jpg', format='jpg', dpi=100, 
                bbox_inches='tight', pad_inches=0.1, facecolor='white')
    
    print("Graphical Abstract saved as 'graphical_abstract.jpg'")
    print(f"Target size: 660x295 pixels")
    
    # Display the plot
    plt.show()
    
    return fig

# Generate the original plot
def create_original_plot():
    plt.figure(figsize=(12, 6))
    sns.barplot(
        data=df,
        x='Model_Name',
        y='Median_Response_Time_ms',
        hue='Arch'
    )
    plt.ylabel('Median Response Time (ms)')
    plt.xlabel('Model')
    plt.title('Median Response Time per Model by Deployment Architecture')
    plt.legend(title='Architecture')
    plt.yticks(
        range(
            int(df['Median_Response_Time_ms'].min() // 100 * 100),
            int(df['Median_Response_Time_ms'].max() // 100 * 100 + 200),
            100
        )
    )
    plt.tight_layout()
    plt.show()

# Create both versions
if __name__ == "__main__":
    print("Creating Graphical Abstract...")
    create_graphical_abstract()
    
    print("\nCreating original detailed plot...")
    create_original_plot()